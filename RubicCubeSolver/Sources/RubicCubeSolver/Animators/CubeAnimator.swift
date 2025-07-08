//
//  Animator.swift
//  RubicCube
//
//  Created by Mateusz Kosikowski on 07/07/2025.
//
import Foundation
import simd

/// Animator class to smoothly animate moves on the cube.
final class CubeAnimator: Animator {
    private(set) var currentMove: Move?
    private var elapsed: TimeInterval = 0
    private var isAnimating = false

    /// Rotation progress in radians for current move [0 .. ±π/2]
    private(set) var currentAngle: Float = 0

    /// Normalized animation progress (0 to 1) for current move
    var progress: Float {
        guard isAnimating, let move = currentMove else { return 0 }
        return min(Float(elapsed / move.duration), 1)
    }

    /// Current move layer index
    private(set) var currentLayer: Int = 0

    /// Current move axis
    private(set) var currentAxis: Move.Axis = .x

    /// Current move direction (1 or -1)
    private(set) var currentDirection: Float = 1

    /// Start a new move animation if none is running
    func start(move: Move) -> Bool {
        guard !isAnimating else { return false }
        currentMove = move
        elapsed = 0
        currentAngle = 0
        currentLayer = move.layer
        currentAxis = move.axis
        currentDirection = move.signedAngleMultiplier
        isAnimating = true
        return true
    }

    /// Update animation progress by deltaTime seconds
    /// Returns the move that just finished, or nil if animation is ongoing or no animation is running
    func update(deltaTime: TimeInterval) -> Move? {
        guard isAnimating, let move = currentMove else { return nil }
        elapsed += deltaTime
        let t = min(elapsed / move.duration, 1)
        let angle = Float(t) * move.anglePerStep * currentDirection
        currentAngle = angle
        if t >= 1 {
            isAnimating = false
            let finishedMove = currentMove
            currentMove = nil
            currentAngle = 0
            return finishedMove
        }
        return nil
    }

    /// Returns the current transform for the cubes in the rotating layer
    /// angle is Current angle in radians for animation
    /// axis is rotation axis
    func rotationMatrix() -> simd_float4x4? {
        guard isAnimating else { return nil }
        let angle = currentAngle
        switch currentAxis {
        case .x: return simd_float4x4(rotationAbout: SIMD3<Float>(1, 0, 0), angle: angle)
        case .y: return simd_float4x4(rotationAbout: SIMD3<Float>(0, 1, 0), angle: angle)
        case .z: return simd_float4x4(rotationAbout: SIMD3<Float>(0, 0, 1), angle: angle)
        }
    }
}
