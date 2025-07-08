//
//  CubeState.swift
//  RubicCube
//
//  Created by Mateusz Kosikowski on 07/07/2025.
//
import Foundation
import simd
import SwiftUI



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
class RubicCubeSolver {
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

                    // Rotate face colors for the cubie (simulate sticker rotation)
                    // Use the same signed direction as the move
                    let dirForColors: Move.Direction = (signed > 0 ? .clockwise : .counterClockwise)
                    newFaceColors[destIndex] = rotateFaceColors(cube.faceColors[i],
                                                                axis: move.axis,
                                                                direction: dirForColors)
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
        cube.transforms = newTransforms
        cube.faceColors = newFaceColors

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

    /// Rotates the 6 face colors of a cubie according to the axis and direction of rotation.
    private func rotateFaceColors(_ colors: [SIMD3<Float>], axis: Move.Axis, direction: Move.Direction) -> [SIMD3<Float>] {
        var newColors = Array(repeating: SIMD3<Float>(0, 0, 0), count: 6)
        switch axis {
        case .x:
            if direction == .clockwise {
                // For R move: +Y → +Z, +Z → -Y, -Y → -Z, -Z → +Y
                newColors[0] = colors[0] // +X stays
                newColors[1] = colors[1] // -X stays
                newColors[2] = colors[4] // +Y ← +Z
                newColors[3] = colors[5] // -Y ← -Z
                newColors[4] = colors[3] // +Z ← -Y
                newColors[5] = colors[2] // -Z ← +Y
            } else {
                // For L move: +Y → -Z, -Z → -Y, -Y → +Z, +Z → +Y
                newColors[0] = colors[0]
                newColors[1] = colors[1]
                newColors[2] = colors[5] // +Y ← -Z
                newColors[3] = colors[4] // -Y ← +Z
                newColors[4] = colors[2] // +Z ← +Y
                newColors[5] = colors[3] // -Z ← -Y
            }
        case .y:
            if direction == .clockwise {
                // For U move: +X → -Z, -Z → -X, -X → +Z, +Z → +X
                newColors[0] = colors[5] // +X ← -Z
                newColors[1] = colors[4] // -X ← +Z
                newColors[2] = colors[2] // +Y stays
                newColors[3] = colors[3] // -Y stays
                newColors[4] = colors[0] // +Z ← +X
                newColors[5] = colors[1] // -Z ← -X
            } else {
                newColors[0] = colors[4]
                newColors[1] = colors[5]
                newColors[2] = colors[2]
                newColors[3] = colors[3]
                newColors[4] = colors[1]
                newColors[5] = colors[0]
            }
        case .z:
            if direction == .clockwise {
                // For F move: +X → +Y, +Y → -X, -X → -Y, -Y → +X
                newColors[0] = colors[2] // +X ← +Y
                newColors[1] = colors[3] // -X ← -Y
                newColors[2] = colors[1] // +Y ← -X
                newColors[3] = colors[0] // -Y ← +X
                newColors[4] = colors[4] // +Z stays
                newColors[5] = colors[5] // -Z stays
            } else {
                newColors[0] = colors[3]
                newColors[1] = colors[2]
                newColors[2] = colors[0]
                newColors[3] = colors[1]
                newColors[4] = colors[4]
                newColors[5] = colors[5]
            }
        }
        return newColors
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
