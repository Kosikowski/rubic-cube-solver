
import Combine
import MetalKit
import simd
import SwiftUI

#if os(macOS)
    import AppKit // for NSView.displayLink
#else
    import QuartzCore // for CADisplayLink
#endif

@MainActor
class RubiksCubeViewModel: ObservableObject {
    enum UserMove: String, CaseIterable {
        case U, R, L, F, B, D, H, V

        var displayName: String {
            rawValue.uppercased()
        }

        func move() -> Move? {
            switch self {
            case .U: return Move(axis: .y, layer: 2, direction: .clockwise)
            case .D: return Move(axis: .y, layer: 0, direction: .clockwise)
            case .L: return Move(axis: .x, layer: 0, direction: .clockwise)
            case .R: return Move(axis: .x, layer: 2, direction: .clockwise)
            case .F: return Move(axis: .z, layer: 2, direction: .clockwise)
            case .B: return Move(axis: .z, layer: 0, direction: .clockwise)
            case .H: return Move(axis: .y, layer: 1, direction: .clockwise)
            case .V: return Move(axis: .x, layer: 1, direction: .clockwise)
            }
        }
    }

    // MARK: state

    var cubeState = CubeState()
    private(set) var animator = Animator()

    private var moveQueue = [Move]()
    private var lastTimestamp: CFTimeInterval = 0

    #if os(macOS)
        private var displayLink: CADisplayLink?
    #else
        private var displayLink: CADisplayLink?
    #endif

    let allMoves: [UserMove] = UserMove.allCases

    init() {}
    deinit {}

    // MARK: public

    func enqueue(move: Move) { moveQueue.append(move) }
    func scramble(movesCount _: Int = 20) { /* … */ }
    func solve() { /* … */ }

    func startDisplayLink(on view: Any) {
        stopDisplayLink()

        #if os(macOS)
            guard let nsView = view as? NSView else { return }
            displayLink = nsView.displayLink(target: self, selector: #selector(displayLinkFired(_:)))
        #else
            guard let mtk = view as? MTKView else { return }
            displayLink = CADisplayLink(target: self, selector: #selector(displayLinkFired(_:)))
        #endif

        displayLink?.add(to: .current, forMode: .common)
    }

    func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
        lastTimestamp = 0
    }

    // MARK: callbacks

    @objc private func displayLinkFired(_ link: CADisplayLink) {
        let ts = link.timestamp
        processFrame(timestamp: ts)
    }

    private func processFrame(timestamp: CFTimeInterval) {
        if lastTimestamp == 0 {
            lastTimestamp = timestamp
            return
        }
        let delta = timestamp - lastTimestamp
        lastTimestamp = timestamp

        if animator.currentMove == nil, !moveQueue.isEmpty {
            if animator.start(move: moveQueue.removeFirst()) {}
        }
        if let finished = animator.update(deltaTime: delta) {
            cubeState.apply(move: finished)
        }
        objectWillChange.send()
    }
}
