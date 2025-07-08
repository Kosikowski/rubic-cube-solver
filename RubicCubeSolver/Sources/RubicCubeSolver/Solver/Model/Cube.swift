//
//  Cube.swift
//  RubicCubeSolver
//
//  Created by Mateusz Kosikowski on 08/07/2025.
//
import Foundation
import simd

/// Represents the 3D state of a Rubik's Cube, including cubie transforms and face colors.
struct Cube {
    /// 3x3x3 array of cubie transforms (local to cube center)
    /// Each cubie transform is a simd_float4x4 matrix representing
    /// the cubie's position and orientation relative to the cube center.
    var transforms: [simd_float4x4]

    /// Colors for each cubie face (6 faces per cubie), 27 cubies total
    /// Each face color is a simd_float3 RGB vector (values from 0 to 1).
    /// The order of faces is [+X, -X, +Y, -Y, +Z, -Z].
    var faceColors: [[simd_float3]]

    /// Position offsets for each cubie (centered at 0,0,0)
    /// Represents the fixed ordering and positions of the 27 cubies in the cube.
    static let cubePositions: [SIMD3<Int>] = {
        var result = [SIMD3<Int>]()
        for z in 0 ..< 3 {
            for y in 0 ..< 3 {
                for x in 0 ..< 3 {
                    result.append(SIMD3<Int>(x, y, z))
                }
            }
        }
        return result
    }()

    /// Initializes the Cube with default identity transforms and empty face colors,
    /// then resets to the solved state.
    init() {
        transforms = Array(repeating: matrix_identity_float4x4, count: 27)
        faceColors = Array(repeating: Array(repeating: SIMD3<Float>(0, 0, 0), count: 6), count: 27)
        reset()
    }

    /// Resets cube transforms and face colors to the solved state.
    mutating func reset() {
        for i in 0 ..< 27 {
            let pos = Cube.cubePositions[i]
            transforms[i] = simd_float4x4(translation: SIMD3<Float>(
                Float(pos.x) - 1,
                Float(pos.y) - 1,
                Float(pos.z) - 1
            ))

            // Initialize face colors for each cubie face in solved state:
            // Order of faces: +X(R), -X(O), +Y(W), -Y(Y), +Z(B), -Z(G)
            // Using standard Rubik's cube color scheme:
            // Right (X+) = Red (1,0,0)
            // Left (X-) = Orange (1,0.5,0)
            // Up (Y+) = White (1,1,1)
            // Down (Y-) = Yellow (1,1,0)
            // Front (Z+) = Blue (0,0,1)
            // Back (Z-) = Green (0,1,0)
            var faces = [SIMD3<Float>](repeating: SIMD3<Float>(0, 0, 0), count: 6)

            // Assign colors only if cubie is on that face (outer layer)
            faces[0] = (pos.x == 2) ? SIMD3<Float>(1, 0, 0) : SIMD3<Float>(0, 0, 0) // +X Red
            faces[1] = (pos.x == 0) ? SIMD3<Float>(1, 0.5, 0) : SIMD3<Float>(0, 0, 0) // -X Orange
            faces[2] = (pos.y == 2) ? SIMD3<Float>(1, 1, 1) : SIMD3<Float>(0, 0, 0) // +Y White
            faces[3] = (pos.y == 0) ? SIMD3<Float>(1, 1, 0) : SIMD3<Float>(0, 0, 0) // -Y Yellow
            faces[4] = (pos.z == 2) ? SIMD3<Float>(0, 0, 1) : SIMD3<Float>(0, 0, 0) // +Z Blue
            faces[5] = (pos.z == 0) ? SIMD3<Float>(0, 1, 0) : SIMD3<Float>(0, 0, 0) // -Z Green

            faceColors[i] = faces
        }
    }
}
