#if os(macOS)
import CoreVideo
#endif
import SwiftUI
import MetalKit
import simd
import Combine

/// ViewModel bridging CubeState and Metal rendering.

@MainActor
class RubiksCubeViewModel: ObservableObject {
    var cubeState = CubeState()
    private(set) var animator = Animator()
    
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
    
    func cleanup() {
        
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
             cubeState.apply(move: move)  // Temporarily disabled sticker update after animation complete
        }
        
        // Remove previous redundant checks and comments about applying moves here
        
        // Publish updates for SwiftUI views to redraw
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
}

