#if os(macOS)
import CoreVideo
#endif
import SwiftUI
import MetalKit
import simd
import Combine

/// ViewModel bridging CubeState and Metal rendering.
class RubiksCubeViewModel: ObservableObject {
    @Published var cubeState = CubeState()
    
    @Published private(set) var animator = Animator()
    private var moveQueue = [Move]()
    
    #if os(macOS)
    private var displayLink: CVDisplayLink?
    private var needsDisplayUpdate = false
    #else
    private var displayLink: CADisplayLink?
    #endif
    private var lastTimestamp: CFTimeInterval = 0
    
    init() {
        startDisplayLink()
    }
    
    deinit {
        #if os(macOS)
        if let displayLink = displayLink {
            CVDisplayLinkStop(displayLink)
        }
        #else
        displayLink?.invalidate()
        #endif
    }
    
    /// Enqueue a move to be executed sequentially.
    func enqueue(move: Move) {
        moveQueue.append(move)
    }
    
    /// Scramble the cube with random moves
    func scramble(movesCount: Int = 20) {
        cubeState.reset()
        moveQueue.removeAll()
        for _ in 0..<movesCount {
            let axis = [Move.Axis.x, .y, .z].randomElement()!
            let layer = Int.random(in: 0...2)
            let direction: Move.Direction = Bool.random() ? .clockwise : .counterClockwise
            enqueue(move: Move(axis: axis, layer: layer, direction: direction))
        }
    }
    
    /// Solve the cube by resetting the state and clearing moves
    func solve() {
        moveQueue.removeAll()
        cubeState.reset()
    }
    
    private func startDisplayLink() {
        #if os(macOS)
        var link: CVDisplayLink?
        CVDisplayLinkCreateWithActiveCGDisplays(&link)
        displayLink = link
        if let displayLink = displayLink {
            CVDisplayLinkSetOutputCallback(displayLink, { (_, inNow, _, _, _, userInfo) -> CVReturn in
                let viewModel = Unmanaged<RubiksCubeViewModel>.fromOpaque(userInfo!).takeUnretainedValue()
                viewModel.cvDisplayLinkFired(time: inNow.pointee)
                return kCVReturnSuccess
            }, UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()))
            CVDisplayLinkStart(displayLink)
        }
        #else
        displayLink = CADisplayLink(target: self, selector: #selector(update))
        displayLink?.add(to: .main, forMode: .default)
        #endif
    }
    
    #if os(macOS)
    private func cvDisplayLinkFired(time: CVTimeStamp) {
        // Convert CVTimeStamp to time interval
        let timestamp = Double(time.videoTime) / Double(time.videoTimeScale)
        DispatchQueue.main.async {
            self.updateDisplayLink(timestamp: timestamp)
        }
    }
    #endif
    
    @objc private func update(link: CADisplayLink) {
        updateDisplayLink(timestamp: link.timestamp)
    }
    
    private func updateDisplayLink(timestamp: CFTimeInterval) {
        if lastTimestamp == 0 {
            lastTimestamp = timestamp
            return
        }
        let deltaTime = timestamp - lastTimestamp
        lastTimestamp = timestamp
        
        if animator.currentMove == nil, !moveQueue.isEmpty {
            // Start next move
            if animator.start(move: moveQueue.first!) {
                moveQueue.removeFirst()
            }
        }
        
        // Updated here as per instructions:
        let finishedMove = animator.update(deltaTime: deltaTime)
        let animating = (animator.currentMove != nil)
        if let move = finishedMove {
            cubeState.apply(move: move)
        }
        
        // Remove previous redundant checks and comments about applying moves here
        
        // Publish updates for SwiftUI views to redraw
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
}

// MARK: - RubiksCubeMetalView

#if os(macOS)
import AppKit

// Custom MTKView subclass to handle mouse events for camera orbit
class RubiksCubeMTKView: MTKView {
    weak var coordinator: Coordinator?
    
    override func mouseDown(with event: NSEvent) {
        coordinator?.mtkViewMouseDown(event)
    }
    
    override func mouseDragged(with event: NSEvent) {
        coordinator?.mtkViewMouseDragged(event)
    }
    
    override func mouseUp(with event: NSEvent) {
        coordinator?.mtkViewMouseUp(event)
    }
}

struct RubiksCubeMetalView: NSViewRepresentable {
    @ObservedObject var viewModel: RubiksCubeViewModel
    
    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }
    
    func makeNSView(context: Context) -> MTKView {
        let mtkView = RubiksCubeMTKView()
        mtkView.device = MTLCreateSystemDefaultDevice()
        mtkView.delegate = context.coordinator
        mtkView.preferredFramesPerSecond = 60
        mtkView.framebufferOnly = false
        mtkView.clearColor = MTLClearColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 1.0)
        mtkView.depthStencilPixelFormat = .depth32Float
        mtkView.coordinator = context.coordinator
        
        // Enable tracking area for mouse events if needed (optional)
        let trackingArea = NSTrackingArea(rect: mtkView.bounds,
                                          options: [.activeAlways, .mouseEnteredAndExited, .mouseMoved, .inVisibleRect],
                                          owner: mtkView,
                                          userInfo: nil)
        mtkView.addTrackingArea(trackingArea)
        
        return mtkView
    }
    
    func updateNSView(_ nsView: MTKView, context: Context) {
        // ViewModel changes trigger redraw automatically.
    }
}
#else
import UIKit
struct RubiksCubeMetalView: UIViewRepresentable {
    @ObservedObject var viewModel: RubiksCubeViewModel
    
    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }
    
    func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.device = MTLCreateSystemDefaultDevice()
        mtkView.delegate = context.coordinator
        mtkView.preferredFramesPerSecond = 60
        mtkView.framebufferOnly = false
        mtkView.clearColor = MTLClearColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 1.0)
        mtkView.depthStencilPixelFormat = .depth32Float
        return mtkView
    }
    
    func updateUIView(_ uiView: MTKView, context: Context) {
        // ViewModel changes trigger redraw automatically.
    }
}
#endif
    
class Coordinator: NSObject, MTKViewDelegate {
    let viewModel: RubiksCubeViewModel
    var pipelineState: MTLRenderPipelineState!
    var commandQueue: MTLCommandQueue!
    
    // Buffers
    var vertexBuffer: MTLBuffer!
    var indexBuffer: MTLBuffer!
    
    // Cubie instance uniform buffer (transforms + colors)
    var instanceUniformBuffer: MTLBuffer!
    
    // Uniforms buffer for view/projection and lighting
    var uniformsBuffer: MTLBuffer!
    
    // Depth stencil state
    var depthStencilState: MTLDepthStencilState!
    
    // Vertex data for a single cubie (a cube)
    struct Vertex {
        var position: SIMD3<Float>
        var normal: SIMD3<Float>
    }
    
    // Uniforms sent to vertex shader
    struct Uniforms {
        var vpMatrix: simd_float4x4
        var lightPos: SIMD3<Float>
        var padding: Float = 0
    }
    
    // Per-instance uniform: model matrix + 6 face colors (RGB per face)
    struct InstanceUniforms {
        var modelMatrix: simd_float4x4
        var faceColors: SIMD3<Float>  // We'll pass colors as 6 * float3 consecutively
    }
    
    struct InstanceData {
        var modelMatrix: simd_float4x4
        var faceColors: [SIMD3<Float>]  // 6 faces
    }
    
    // We will store modelMatrix + 6 face colors per cubie
    struct InstanceUniformsPacked {
        var modelMatrix: simd_float4x4
        var faceColors: (SIMD3<Float>, SIMD3<Float>, SIMD3<Float>, SIMD3<Float>, SIMD3<Float>, SIMD3<Float>)
    }
    
    // --- Camera Orbit Support (macOS only for now) ---
    // Azimuth and elevation angles in radians
    var cameraAzimuth: Float = 0
    var cameraElevation: Float = .pi / 8  // ~22.5 degrees
    var cameraDistance: Float = 6
    var lastMouseLocation: CGPoint = .zero
    var isDraggingCamera: Bool = false
    
    init(viewModel: RubiksCubeViewModel) {
        self.viewModel = viewModel
        super.init()
        setupMetal()
        createBuffers()
    }
    
    func setupMetal() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal device not available")
        }
        commandQueue = device.makeCommandQueue()
        do {
            let library = device.makeDefaultLibrary()
            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            pipelineDescriptor.vertexFunction = library?.makeFunction(name: "vertex_main")
            pipelineDescriptor.fragmentFunction = library?.makeFunction(name: "fragment_main")
            pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            pipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
            pipelineDescriptor.vertexDescriptor = makeVertexDescriptor()
            pipelineDescriptor.isRasterizationEnabled = true
            // Removed line: pipelineDescriptor.cullMode = .none
            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
            
            let depthDescriptor = MTLDepthStencilDescriptor()
            depthDescriptor.depthCompareFunction = .less
            depthDescriptor.isDepthWriteEnabled = true
            depthStencilState = device.makeDepthStencilState(descriptor: depthDescriptor)
            
        } catch {
            fatalError("Metal pipeline error: \(error)")
        }
    }
    
    func makeVertexDescriptor() -> MTLVertexDescriptor {
        let vertexDescriptor = MTLVertexDescriptor()
        // Positions
        vertexDescriptor.attributes[0].format = .float3
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0
        // Normals
        vertexDescriptor.attributes[1].format = .float3
        vertexDescriptor.attributes[1].offset = MemoryLayout<SIMD3<Float>>.stride
        vertexDescriptor.attributes[1].bufferIndex = 0
        vertexDescriptor.layouts[0].stride = MemoryLayout<Vertex>.stride
        vertexDescriptor.layouts[0].stepFunction = .perVertex
        
        // Instance attributes: model matrix 4x4 (4 x float4 attributes)
        // We'll use buffer index 1 for instance data
        
        // Model matrix columns as 4 float4 attributes
        for i in 0..<4 {
            vertexDescriptor.attributes[2 + i].format = .float4
            vertexDescriptor.attributes[2 + i].offset = i * MemoryLayout<SIMD4<Float>>.stride
            vertexDescriptor.attributes[2 + i].bufferIndex = 1
        }
        // Face colors (6 x float3) - 6 * 12 bytes = 72 bytes offset after model matrix
        // We'll pack face colors starting at offset 64 bytes (modelMatrix = 64 bytes)
        let faceColorsOffset = MemoryLayout<simd_float4x4>.stride
        for i in 0..<6 {
            vertexDescriptor.attributes[6 + i].format = .float3
            vertexDescriptor.attributes[6 + i].offset = faceColorsOffset + i * MemoryLayout<SIMD3<Float>>.stride
            vertexDescriptor.attributes[6 + i].bufferIndex = 1
        }
        vertexDescriptor.layouts[1].stride = faceColorsOffset + 6 * MemoryLayout<SIMD3<Float>>.stride
        vertexDescriptor.layouts[1].stepFunction = .perInstance
        
        return vertexDescriptor
    }
    
    func createBuffers() {
        let device = commandQueue.device
        
        // Cube vertices - unit cube centered at origin, size 1 (each cubie is 1 unit cube)
        // We'll define 24 vertices (4 per face * 6 faces) to have proper normals.
        // This allows flat shading per face.
        
        let vertices: [Vertex] = [
            // +X face (Right)
            Vertex(position: SIMD3<Float>(0.5, -0.5, -0.5), normal: SIMD3<Float>(1, 0, 0)),
            Vertex(position: SIMD3<Float>(0.5, 0.5, -0.5), normal: SIMD3<Float>(1, 0, 0)),
            Vertex(position: SIMD3<Float>(0.5, 0.5, 0.5), normal: SIMD3<Float>(1, 0, 0)),
            Vertex(position: SIMD3<Float>(0.5, -0.5, 0.5), normal: SIMD3<Float>(1, 0, 0)),
            
            // -X face (Left)
            Vertex(position: SIMD3<Float>(-0.5, -0.5, 0.5), normal: SIMD3<Float>(-1, 0, 0)),
            Vertex(position: SIMD3<Float>(-0.5, 0.5, 0.5), normal: SIMD3<Float>(-1, 0, 0)),
            Vertex(position: SIMD3<Float>(-0.5, 0.5, -0.5), normal: SIMD3<Float>(-1, 0, 0)),
            Vertex(position: SIMD3<Float>(-0.5, -0.5, -0.5), normal: SIMD3<Float>(-1, 0, 0)),
            
            // +Y face (Top)
            Vertex(position: SIMD3<Float>(-0.5, 0.5, -0.5), normal: SIMD3<Float>(0, 1, 0)),
            Vertex(position: SIMD3<Float>(-0.5, 0.5, 0.5), normal: SIMD3<Float>(0, 1, 0)),
            Vertex(position: SIMD3<Float>(0.5, 0.5, 0.5), normal: SIMD3<Float>(0, 1, 0)),
            Vertex(position: SIMD3<Float>(0.5, 0.5, -0.5), normal: SIMD3<Float>(0, 1, 0)),
            
            // -Y face (Bottom)
            Vertex(position: SIMD3<Float>(-0.5, -0.5, 0.5), normal: SIMD3<Float>(0, -1, 0)),
            Vertex(position: SIMD3<Float>(-0.5, -0.5, -0.5), normal: SIMD3<Float>(0, -1, 0)),
            Vertex(position: SIMD3<Float>(0.5, -0.5, -0.5), normal: SIMD3<Float>(0, -1, 0)),
            Vertex(position: SIMD3<Float>(0.5, -0.5, 0.5), normal: SIMD3<Float>(0, -1, 0)),
            
            // +Z face (Front)
            Vertex(position: SIMD3<Float>(-0.5, -0.5, 0.5), normal: SIMD3<Float>(0, 0, 1)),
            Vertex(position: SIMD3<Float>(0.5, -0.5, 0.5), normal: SIMD3<Float>(0, 0, 1)),
            Vertex(position: SIMD3<Float>(0.5, 0.5, 0.5), normal: SIMD3<Float>(0, 0, 1)),
            Vertex(position: SIMD3<Float>(-0.5, 0.5, 0.5), normal: SIMD3<Float>(0, 0, 1)),
            
            // -Z face (Back)
            Vertex(position: SIMD3<Float>(0.5, -0.5, -0.5), normal: SIMD3<Float>(0, 0, -1)),
            Vertex(position: SIMD3<Float>(-0.5, -0.5, -0.5), normal: SIMD3<Float>(0, 0, -1)),
            Vertex(position: SIMD3<Float>(-0.5, 0.5, -0.5), normal: SIMD3<Float>(0, 0, -1)),
            Vertex(position: SIMD3<Float>(0.5, 0.5, -0.5), normal: SIMD3<Float>(0, 0, -1)),
        ]
        
        vertexBuffer = device.makeBuffer(bytes: vertices,
                                         length: MemoryLayout<Vertex>.stride * vertices.count,
                                         options: [])
        
        // Indices for triangles (6 faces, 2 triangles per face, 3 indices each = 36)
        // Each face uses 4 vertices in order: 0,1,2,3
        let indices: [UInt16] = [
            0, 1, 2, 0, 2, 3,       // +X
            4, 5, 6, 4, 6, 7,       // -X
            8, 9, 10, 8, 10, 11,    // +Y
            12, 13, 14, 12, 14, 15, // -Y
            16, 17, 18, 16, 18, 19, // +Z
            20, 21, 22, 20, 22, 23  // -Z
        ]
        
        indexBuffer = device.makeBuffer(bytes: indices,
                                        length: MemoryLayout<UInt16>.stride * indices.count,
                                        options: [])
        
        // Create instance uniform buffer for 27 cubies
        // Replace original allocation with: (buffer fix)
        let instanceStride = MemoryLayout<simd_float4x4>.stride + MemoryLayout<SIMD3<Float>>.stride * 6
        instanceUniformBuffer = device.makeBuffer(length: instanceStride * 27, options: [])
        
        // Uniforms buffer for VP matrix and light
        uniformsBuffer = device.makeBuffer(length: MemoryLayout<Uniforms>.stride, options: [])
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // Nothing needed here for now
    }
    
    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let descriptor = view.currentRenderPassDescriptor,
              let device = view.device,
              let commandQueue = commandQueue else { return }
        
        if descriptor.depthAttachment == nil {
            fatalError("No depth attachment in render pass descriptor! Check your MTKView depthStencilPixelFormat and that the view is onscreen.")
        }
        
        let commandBuffer = commandQueue.makeCommandBuffer()
        guard let encoder = commandBuffer?.makeRenderCommandEncoder(descriptor: descriptor) else {
            commandBuffer?.commit()
            return
        }
        
        encoder.setRenderPipelineState(pipelineState)
        encoder.setCullMode(.none)
        encoder.setDepthStencilState(depthStencilState)
        
        // Setup camera: view-projection matrix
        let aspect = Float(view.drawableSize.width / view.drawableSize.height)
        let fov: Float = 90 * (.pi / 180)
        let near: Float = 0.1
        let far: Float = 100
        
        let projectionMatrix = simd_float4x4(perspectiveFov: fov, aspectRatio: aspect, nearZ: near, farZ: far)
        
        // --- Camera Orbit calculations ---
        // Calculate eye position from spherical coordinates: azimuth, elevation, distance
        let r = cameraDistance
        let eye = SIMD3<Float>(
            r * cos(cameraElevation) * sin(cameraAzimuth),
            r * sin(cameraElevation),
            r * cos(cameraElevation) * cos(cameraAzimuth)
        )
        
        // Camera looks at the center of cube at (0,0,0)
        let center = SIMD3<Float>(0, 0, 0)
        let up = SIMD3<Float>(0, 1, 0)
        let viewMatrix = simd_float4x4(lookAtEye: eye, center: center, up: up)
        
        let vpMatrix = projectionMatrix * viewMatrix
        
        // Light position in world space (e.g. same as eye)
        let lightPos = eye
        
        // Upload uniforms
        var uniforms = Uniforms(vpMatrix: vpMatrix, lightPos: lightPos)
        memcpy(uniformsBuffer.contents(), &uniforms, MemoryLayout<Uniforms>.stride)
        encoder.setVertexBuffer(uniformsBuffer, offset: 0, index: 2)
        
        // Prepare per-instance uniforms buffer with transforms + face colors
        // Size per instance = modelMatrix (64 bytes) + 6 * float3 (72 bytes) = 136 bytes
        // We'll pack face colors consecutively after modelMatrix
        
        let instanceBufferRawPointer = UnsafeMutableRawPointer(instanceUniformBuffer.contents())
        
        // Print first 5 cubie transforms
//        print("First 5 cubie transforms:")
//        for idx in 0..<5 {
//            print(viewModel.cubeState.transforms[idx])
//        }
        
        // Print camera and model bounding info
//        print("Camera eye position: \(eye)")
        var minPoint = SIMD3<Float>(Float.greatestFiniteMagnitude, Float.greatestFiniteMagnitude, Float.greatestFiniteMagnitude)
        var maxPoint = SIMD3<Float>(-Float.greatestFiniteMagnitude, -Float.greatestFiniteMagnitude, -Float.greatestFiniteMagnitude)

        for i in 0..<27 {
            let modelMatrix = viewModel.cubeState.transforms[i]
            // Each cubie is a unit cube centered at its transform's translation.
            let pos = SIMD3<Float>(modelMatrix.columns.3.x, modelMatrix.columns.3.y, modelMatrix.columns.3.z)
            minPoint = min(minPoint, pos - SIMD3<Float>(0.5, 0.5, 0.5))
            maxPoint = max(maxPoint, pos + SIMD3<Float>(0.5, 0.5, 0.5))
        }
//        print("Cube bounding box: min=\(minPoint), max=\(maxPoint)")
        
        // Copy cubie transforms and face colors, applying animator rotation if needed for rotating layer
        let cubeState = viewModel.cubeState
        let animator = viewModel.animator
        
        // Rotation matrix for current move animation (optional)
        let rotationMatrixOpt = animator.rotationMatrix()
        let rotatingAxis = animator.currentAxis
        let rotatingLayer = animator.currentLayer
        
        for i in 0..<27 {
            let pos = CubeState.cubePositions[i]
            /// fixe for buffer
            let baseOffset = i * (MemoryLayout<simd_float4x4>.stride + MemoryLayout<SIMD3<Float>>.stride * 6)
            
            // Determine if this cubie is on the rotating layer:
            var modelMatrix = cubeState.transforms[i]
            
            if let rotationMatrix = rotationMatrixOpt {
                // Check if cubie is in rotating layer
                let layerIndex: Int
                switch rotatingAxis {
                case .x: layerIndex = pos.x
                case .y: layerIndex = pos.y
                case .z: layerIndex = pos.z
                }
                if layerIndex == rotatingLayer {
                    // Apply animation rotation around axis center
                    // Translate cubie center to origin (cube center at 0,0,0), rotate, translate back
//                    let translationToCenter = simd_float4x4(translation: -SIMD3<Float>(0,0,0))
//                    let translationBack = simd_float4x4(translation: SIMD3<Float>(0,0,0))
                    // We can just multiply rotation * modelMatrix because modelMatrix already includes position offset
                    modelMatrix = rotationMatrix * modelMatrix
                }
            }
            
            // Write modelMatrix (float4x4)
            let modelMatrixPtr = instanceBufferRawPointer.advanced(by: baseOffset).assumingMemoryBound(to: simd_float4x4.self)
            modelMatrixPtr.pointee = modelMatrix
            
            // Write face colors as 6 float3 sequentially after modelMatrix
            let colorsStart = baseOffset + MemoryLayout<simd_float4x4>.stride
            let colorsPtr = instanceBufferRawPointer.advanced(by: colorsStart).assumingMemoryBound(to: SIMD3<Float>.self)
            let colors = cubeState.faceColors[i]
            for f in 0..<6 {
                colorsPtr[f] = colors[f]
            }
        }
        
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        encoder.setVertexBuffer(instanceUniformBuffer, offset: 0, index: 1)
        // Removed encoder.setIndexBuffer(indexBuffer, offset: 0, indexType: .uint16)
        
        // Draw instanced geometry: 1 cubie only, 36 indices each
        encoder.drawIndexedPrimitives(type: .triangle,
                                      indexCount: 36,
                                      indexType: MTLIndexType.uint16,
                                      indexBuffer: indexBuffer,
                                      indexBufferOffset: 0,
                                      instanceCount: 27)
        
        encoder.endEncoding()
        commandBuffer?.present(drawable)
        commandBuffer?.commit()
    }
    
    // MARK: - Mouse event handlers for camera orbit (macOS only)
    #if os(macOS)
    func mtkViewMouseDown(_ event: NSEvent) {
        isDraggingCamera = true
        lastMouseLocation = event.locationInWindow
    }
    
    func mtkViewMouseDragged(_ event: NSEvent) {
        guard isDraggingCamera else { return }
        let currentLocation = event.locationInWindow
        let deltaX = Float(currentLocation.x - lastMouseLocation.x)
        let deltaY = Float(currentLocation.y - lastMouseLocation.y)
        
        // Adjust azimuth and elevation based on mouse movement
        // Sensitivity factors can be adjusted
        let sensitivity: Float = 0.005
        cameraAzimuth -= deltaX * sensitivity
        cameraElevation -= deltaY * sensitivity
        
        // Clamp elevation between -85 and +85 degrees (in radians)
        let maxElevation: Float = (.pi / 2) * 0.94
        let minElevation: Float = -maxElevation
        cameraElevation = min(max(cameraElevation, minElevation), maxElevation)
        
        lastMouseLocation = currentLocation
        
        // Request redraw
        if let mtkView = event.window?.contentView?.subviews.compactMap({ $0 as? MTKView }).first {
            mtkView.setNeedsDisplay(mtkView.bounds)
        }
    }
    
    func mtkViewMouseUp(_ event: NSEvent) {
        isDraggingCamera = false
    }
    #endif
}


// MARK: - simd_float4x4 Extensions for common transforms

extension simd_float4x4 {
    init(translation t: SIMD3<Float>) {
        self = matrix_identity_float4x4
        columns.3 = SIMD4<Float>(t.x, t.y, t.z, 1)
    }
    
    init(rotationAbout axis: SIMD3<Float>, angle: Float) {
        let a = normalize(axis)
        let x = a.x, y = a.y, z = a.z
        let c = cos(angle)
        let s = sin(angle)
        let mc = 1 - c
        
        self.init(SIMD4<Float>(c + mc*x*x,      mc*x*y + z*s,    mc*x*z - y*s, 0),
                  SIMD4<Float>(mc*x*y - z*s,    c + mc*y*y,      mc*y*z + x*s, 0),
                  SIMD4<Float>(mc*x*z + y*s,    mc*y*z - x*s,    c + mc*z*z,   0),
                  SIMD4<Float>(0,               0,               0,            1))
    }
    
    init(perspectiveFov fovY: Float, aspectRatio: Float, nearZ: Float, farZ: Float) {
        let yScale = 1 / tan(fovY * 0.5)
        let xScale = yScale / aspectRatio
        let zRange = farZ - nearZ
        let zScale = -(farZ + nearZ) / zRange
        let wzScale = -2 * farZ * nearZ / zRange
        
        self.init(SIMD4<Float>(xScale, 0, 0, 0),
                  SIMD4<Float>(0, yScale, 0, 0),
                  SIMD4<Float>(0, 0, zScale, -1),
                  SIMD4<Float>(0, 0, wzScale, 0))
    }
    
    init(lookAtEye eye: SIMD3<Float>, center: SIMD3<Float>, up: SIMD3<Float>) {
        let z = simd_normalize(eye - center)
        let x = simd_normalize(simd_cross(up, z))
        let y = simd_cross(z, x)
        
        let t = SIMD3<Float>(
            -simd_dot(x, eye),
            -simd_dot(y, eye),
            -simd_dot(z, eye)
        )
        
        self.init(SIMD4<Float>(x.x, y.x, z.x, 0),
                  SIMD4<Float>(x.y, y.y, z.y, 0),
                  SIMD4<Float>(x.z, y.z, z.z, 0),
                  SIMD4<Float>(t.x, t.y, t.z, 1))
    }
}

