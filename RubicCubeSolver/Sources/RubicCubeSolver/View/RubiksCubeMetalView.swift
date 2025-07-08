//
//  RubiksCubeMetalView.swift
//  RubicCube
//
//  Created by Mateusz Kosikowski on 08/07/2025.
//

import Combine
import class Foundation.Bundle
import MetalKit
import simd
import SwiftUI

let numberOfCubiesDisplayed = 27

#if os(macOS)
    import AppKit // For NSView and displayLink
#endif

// Custom MTKView subclass to handle mouse events for camera orbit
#if os(macOS)
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
#endif

struct RubiksCubeMetalView: View {
    @ObservedObject var viewModel: RubiksCubeViewModel

    var body: some View {
        MetalContainer(viewModel: viewModel)
    }
}

#if os(macOS)
    struct MetalContainer: NSViewRepresentable {
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

            // Enable tracking area for mouse events
            let trackingArea = NSTrackingArea(rect: mtkView.bounds,
                                              options: [.activeAlways, .mouseEnteredAndExited, .mouseMoved, .inVisibleRect],
                                              owner: mtkView,
                                              userInfo: nil)
            mtkView.addTrackingArea(trackingArea)

            // Start the new display link on this view
            viewModel.startDisplayLink(on: mtkView)

            return mtkView
        }

        func updateNSView(_: MTKView, context _: Context) {
            // ViewModel changes trigger redraw automatically.
        }

        static func dismantleNSView(_: MTKView, coordinator: Coordinator) {
            coordinator.viewModel.stopDisplayLink()
        }
    }
#else

    // iOS / tvOS version unchanged except for added pan gesture recognizer
    struct MetalContainer: UIViewRepresentable {
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

            // Add pan gesture recognizer for camera orbit
            let panGesture = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePanGesture(_:)))
            mtkView.addGestureRecognizer(panGesture)

            // Start the display link on iOS
            viewModel.startDisplayLink(on: mtkView)

            return mtkView
        }

        func updateUIView(_: MTKView, context _: Context) {
            // ViewModel changes trigger redraw automatically.
        }

        static func dismantleUIView(_: MTKView, coordinator: Coordinator) {
            coordinator.viewModel.stopDisplayLink()
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
        var faceColors: SIMD3<Float> // We'll pass colors as 6 * float3 consecutively
    }

    struct InstanceData {
        var modelMatrix: simd_float4x4
        var faceColors: [SIMD3<Float>] // 6 faces
    }

    // We will store modelMatrix + 6 face colors per cubie
    struct InstanceUniformsPacked {
        var modelMatrix: simd_float4x4
        var faceColors: (SIMD3<Float>, SIMD3<Float>, SIMD3<Float>, SIMD3<Float>, SIMD3<Float>, SIMD3<Float>)
    }

    // --- Camera Orbit Support (macOS only for now) ---
    // Azimuth and elevation angles in radians
    var cameraAzimuth: Float = 0
    var cameraElevation: Float = .pi / 8 // ~22.5 degrees
    var cameraDistance: Float = 6
    var lastMouseLocation: CGPoint = .zero
    var isDraggingCamera: Bool = false
    let instanceStride = MemoryLayout<simd_float4x4>.stride // 64
        + MemoryLayout<SIMD4<Float>>.stride * 6

    // --- Added iOS/tvOS pan gesture support for camera orbit ---
    #if !os(macOS)
        var lastPanLocation: CGPoint = .zero
    #endif

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
            #if SWIFT_PACKAGE
                let library: MTLLibrary
                if let url = Bundle.module.url(forResource: "default", withExtension: "metallib") {
                    library = try device.makeLibrary(URL: url)
                } else {
                    library = try device.makeDefaultLibrary(bundle: .main)
                }
            #else
                let library = device.makeDefaultLibrary()
            #endif
            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            pipelineDescriptor.vertexFunction = library.makeFunction(name: "vertex_main")
            pipelineDescriptor.fragmentFunction = library.makeFunction(name: "fragment_main")
            pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

            let colorAttachment = pipelineDescriptor.colorAttachments[0]
            colorAttachment?.isBlendingEnabled = true
            colorAttachment?.rgbBlendOperation = .add
            colorAttachment?.alphaBlendOperation = .add
            colorAttachment?.sourceRGBBlendFactor = .sourceAlpha
            colorAttachment?.sourceAlphaBlendFactor = .sourceAlpha
            colorAttachment?.destinationRGBBlendFactor = .oneMinusSourceAlpha
            colorAttachment?.destinationAlphaBlendFactor = .oneMinusSourceAlpha

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
        for i in 0 ..< 4 {
            vertexDescriptor.attributes[2 + i].format = .float4
            vertexDescriptor.attributes[2 + i].offset = i * MemoryLayout<SIMD4<Float>>.stride
            vertexDescriptor.attributes[2 + i].bufferIndex = 1
        }
        // Face colors (6 x float3) - 6 * 12 bytes = 72 bytes offset after model matrix
        // We'll pack face colors starting at offset 64 bytes (modelMatrix = 64 bytes)
        let faceColorsOffset = MemoryLayout<simd_float4x4>.stride
        for i in 0 ..< 6 {
            vertexDescriptor.attributes[6 + i].format = .float4 // 16 bytes
            vertexDescriptor.attributes[6 + i].offset = 64 + i * 16 // not 12
            vertexDescriptor.attributes[6 + i].bufferIndex = 1
        }
        vertexDescriptor.layouts[1].stride = instanceStride // faceColorsOffset + 6 * MemoryLayout<SIMD3<Float>>.stride
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
            0, 1, 2, 0, 2, 3, // +X
            4, 5, 6, 4, 6, 7, // -X
            8, 9, 10, 8, 10, 11, // +Y
            12, 13, 14, 12, 14, 15, // -Y
            16, 17, 18, 16, 18, 19, // +Z
            20, 21, 22, 20, 22, 23, // -Z
        ]

        indexBuffer = device.makeBuffer(bytes: indices,
                                        length: MemoryLayout<UInt16>.stride * indices.count,
                                        options: [])

        // Create instance uniform buffer for 27 cubies
        // Replace original allocation with: (buffer fix)
//        // 1.  keep one authoritative value
//        let instanceStride = MemoryLayout<simd_float4x4>.stride      // 64
//                           + MemoryLayout<SIMD4<Float>>.stride * 6   // 16 × 6 = 96
        // total = 160
        instanceUniformBuffer = device.makeBuffer(length: instanceStride * 27,
                                                  options: [])

        // Uniforms buffer for VP matrix and light
        uniformsBuffer = device.makeBuffer(length: MemoryLayout<Uniforms>.stride, options: [])
    }

    func mtkView(_: MTKView, drawableSizeWillChange _: CGSize) {
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

        // Compute animated transforms for all cubies via Animator abstraction
        let cubieTransforms = viewModel.animator.cubieTransforms(for: viewModel.solver)
        for i in 0 ..< 27 {
            let baseOffset = i * instanceStride

            // Use animator-provided transform
            let modelMatrix = cubieTransforms[i]
            let modelMatrixPtr = instanceBufferRawPointer.advanced(by: baseOffset).assumingMemoryBound(to: simd_float4x4.self)
            modelMatrixPtr.pointee = modelMatrix

            // TODO: Face colors could also be fetched via an abstraction if ever needed
            let coloursStart = baseOffset + MemoryLayout<simd_float4x4>.stride
            let coloursPtr = instanceBufferRawPointer
                .advanced(by: coloursStart)
                .assumingMemoryBound(to: SIMD4<Float>.self)
            for f in 0 ..< 6 {
                let c = viewModel.solver.cube.faceColors[i][f]
                coloursPtr[f] = SIMD4<Float>(c, 0)
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
                                      instanceCount: numberOfCubiesDisplayed)

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

        @MainActor func mtkViewMouseDragged(_ event: NSEvent) {
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

        func mtkViewMouseUp(_: NSEvent) {
            isDraggingCamera = false
        }
    #else
        // iOS / tvOS pan gesture handler for camera orbit
        @MainActor
        @objc func handlePanGesture(_ gestureRecognizer: UIPanGestureRecognizer) {
            guard let mtkView = gestureRecognizer.view as? MTKView else { return }

            switch gestureRecognizer.state {
            case .began:
                isDraggingCamera = true
                lastPanLocation = gestureRecognizer.location(in: mtkView)
            case .changed:
                guard isDraggingCamera else { return }
                let currentLocation = gestureRecognizer.location(in: mtkView)
                let deltaX = Float(currentLocation.x - lastPanLocation.x)
                let deltaY = Float(currentLocation.y - lastPanLocation.y)

                // Adjust azimuth and elevation based on pan movement
                let sensitivity: Float = 0.005
                cameraAzimuth -= deltaX * sensitivity
                cameraElevation += deltaY * sensitivity

                // Clamp elevation between -85 and +85 degrees (in radians)
                let maxElevation: Float = (.pi / 2) * 0.94
                let minElevation: Float = -maxElevation
                cameraElevation = min(max(cameraElevation, minElevation), maxElevation)

                lastPanLocation = currentLocation

                // Request redraw
                mtkView.setNeedsDisplay(mtkView.bounds)
            case .ended, .cancelled, .failed:
                isDraggingCamera = false
            default:
                break
            }
        }
    #endif
}
