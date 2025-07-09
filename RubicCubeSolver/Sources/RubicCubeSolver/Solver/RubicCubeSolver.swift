//
//  CubeState.swift
//  RubicCube
//
//  Created by Mateusz Kosikowski on 07/07/2025.
//
import Foundation
import simd
import SwiftUI

/// Protocol defining the requirements for a Rubik's Cube solver.
/// Any solver must have a cube property, be able to reset its state,
/// and apply moves to the cube.
protocol Solver {
    var cube: Cube { get set }
    func reset()
    func apply(move: Move)
}

extension Move.Axis {
    var index: Int {
        switch self {
        case .x: return 0
        case .y: return 1
        case .z: return 2
        }
    }
}

/// Acts on a `Cube` state to perform Rubik's Cube moves and update cube state accordingly.
/// Does not store cube state internally but manipulates the passed-in `Cube` instance.
/// This separation allows for cleaner state management and easier state sharing or persistence.
class RubicCubeSolver: Solver {
    /// The cube state that this solver manipulates.
    var cube: Cube

    /// Enables debug prints of the cube state before and after moves.
    var enablePrints = false

    init(cube: Cube = Cube()) {
        self.cube = cube
    }

    /// Resets the internal cube state to the solved state by delegating to Cube's reset.
    func reset() {
        cube.reset()
    }

    /// Applies a completed move's rotation to the internal cube state transforms and face colors.
    /// This permanently updates the cube's transforms and face colors.
    func apply(move: Move) {
        if enablePrints {
            print("Before move: \(move)")
            for i in 0 ..< 27 {
                let pos = Cube.cubePositions[i]
                let layerIndex: Int
                switch move.axis {
                case .x: layerIndex = pos.x
                case .y: layerIndex = pos.y
                case .z: layerIndex = pos.z
                }
                if layerIndex == move.layer {
                    print("Cubie at \(pos): old faceColors=", cube.faceColors[i].map { String(format: "[%.2f %.2f %.2f]", $0.x, $0.y, $0.z) })
                }
            }
        }

        // Rotation matrix for the specified move axis and signed angle
        let signed = move.signedAngleMultiplier
        let rotation = simd_float4x4(rotationAbout: axisVector(move.axis),
                                     angle: move.anglePerStep * signed)

        // Create copies of the cube's transforms and faceColors to update
        var newTransforms = cube.transforms
        var newFaceColors = cube.faceColors

        // Iterate over all cubies to find those in the layer to rotate
        for i in 0 ..< 27 {
            let pos = Cube.cubePositions[i]
            let layerIndex: Int
            switch move.axis {
            case .x: layerIndex = pos.x
            case .y: layerIndex = pos.y
            case .z: layerIndex = pos.z
            }

            if layerIndex == move.layer {
                // Rotate the cubie's position vector about the axis center (cube center at (1,1,1))
                let posf = SIMD3<Float>(Float(pos.x), Float(pos.y), Float(pos.z))
                let centeredPos = posf - SIMD3<Float>(1, 1, 1)
                let rotatedCenteredPos4 = (rotation * SIMD4<Float>(centeredPos, 1))
                let rotatedCenteredPos = SIMD3<Float>(rotatedCenteredPos4.x, rotatedCenteredPos4.y, rotatedCenteredPos4.z)
                let rotatedPos = rotatedCenteredPos + SIMD3<Float>(1, 1, 1)

                // Round the rotated position to nearest integer to find the destination cubie index
                let roundedPos = SIMD3<Int>(Int(round(rotatedPos.x)), Int(round(rotatedPos.y)), Int(round(rotatedPos.z)))

                // Find index of cubie at the rotated position
                if let destIndex = Cube.cubePositions.firstIndex(where: { $0 == roundedPos }) {
                    // Rotate the transform accordingly:
                    // Remove translation, apply rotation, then translate back to new position
                    let translation = simd_float4x4(translation: -SIMD3<Float>(Float(pos.x) - 1, Float(pos.y) - 1, Float(pos.z) - 1))
                    let invTranslation = simd_float4x4(translation: SIMD3<Float>(Float(roundedPos.x) - 1, Float(roundedPos.y) - 1, Float(roundedPos.z) - 1))
                    newTransforms[destIndex] = invTranslation * rotation * translation * cube.transforms[i]

                    newFaceColors[destIndex] = cube.faceColors[i]
                }
            }
        }

        if enablePrints {
            print("After move: \(move)")
            for i in 0 ..< 27 {
                let pos = Cube.cubePositions[i]
                let layerIndex: Int
                switch move.axis {
                case .x: layerIndex = pos.x
                case .y: layerIndex = pos.y
                case .z: layerIndex = pos.z
                }
                if layerIndex == move.layer {
                    print("Cubie at \(pos): new faceColors=", newFaceColors[i].map { String(format: "[%.2f %.2f %.2f]", $0.x, $0.y, $0.z) })
                }
            }
        }

        // Commit the updated transforms and face colors back to the cube state
        for i in 0 ..< 27 {
            cube.cubies[i].transform = newTransforms[i]
            cube.cubies[i].faceColors = newFaceColors[i]
        }

        if enablePrints {
            // Example validation print for +X face colors on the right layer
            for i in 0 ..< 27 {
                let pos = Cube.cubePositions[i]
                let colors = cube.faceColors[i]
                if pos.x == 2, colors[0] != SIMD3<Float>(1, 0, 0), colors[0] != SIMD3<Float>(0, 0, 0) {
                    print("Invalid +X color at \(pos): \(colors[0])")
                }
                // Additional face checks can be added here similarly
            }
        }
    }

    /// Returns axis unit vector for Move.Axis
    private func axisVector(_ axis: Move.Axis) -> SIMD3<Float> {
        switch axis {
        case .x: return SIMD3<Float>(1, 0, 0)
        case .y: return SIMD3<Float>(0, 1, 0)
        case .z: return SIMD3<Float>(0, 0, 1)
        }
    }
}
