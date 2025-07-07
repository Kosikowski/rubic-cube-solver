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

//extension float4x4 {
//    init(translation t: SIMD3<Float>) {
//        self = matrix_identity_float4x4
//        self.columns.3 = SIMD4<Float>(t.x, t.y, t.z, 1)
//    }
//    init(_ q: simd_quatf) {
//        let m = matrix_float4x4(q)
//        self.init()
//        self.columns = m.columns
//    }
//}

/// Represents the state of the Rubik's Cube.
class CubeState {
    /// 3x3x3 array of cubie transforms (local to cube center)
    /// Each cubie transform is simd_float4x4
    private(set) var transforms: [simd_float4x4]
    
    /// Colors for each cubie face (6 faces), 27 cubies
    /// Each face color is simd_float3 RGB (0..1)
    private(set) var faceColors: [[simd_float3]]  // 27 elements, each with 6 face colors
    
    /// Position offsets for each cubie (centered at 0,0,0)
    static let cubePositions: [SIMD3<Int>] = {
        var result = [SIMD3<Int>]()
        for z in 0..<3 {
            for y in 0..<3 {
                for x in 0..<3 {
                    result.append(SIMD3<Int>(x,y,z))
                }
            }
        }
        return result
    }()
    
    init() {
        transforms = Array(repeating: matrix_identity_float4x4, count: 27)
        faceColors = Array(repeating: Array(repeating: SIMD3<Float>(0,0,0), count: 6), count: 27)
        reset()
    }
    
    /// Resets cube transforms and face colors to solved state.
    func reset() {
        for i in 0..<27 {
            let pos = CubeState.cubePositions[i]
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
            var faces = [SIMD3<Float>](repeating: SIMD3<Float>(0,0,0), count: 6)
            
            // Assign colors only if cubie is on that face (outer layer)
            faces[0] = (pos.x == 2) ? SIMD3<Float>(1, 0, 0) : SIMD3<Float>(0,0,0)    // +X Red
            faces[1] = (pos.x == 0) ? SIMD3<Float>(1, 0.5, 0) : SIMD3<Float>(0,0,0)  // -X Orange
            faces[2] = (pos.y == 2) ? SIMD3<Float>(1, 1, 1) : SIMD3<Float>(0,0,0)    // +Y White
            faces[3] = (pos.y == 0) ? SIMD3<Float>(1, 1, 0) : SIMD3<Float>(0,0,0)    // -Y Yellow
            faces[4] = (pos.z == 2) ? SIMD3<Float>(0, 0, 1) : SIMD3<Float>(0,0,0)    // +Z Blue
            faces[5] = (pos.z == 0) ? SIMD3<Float>(0, 1, 0) : SIMD3<Float>(0,0,0)    // -Z Green
            
            faceColors[i] = faces
        }
    }
    
    /// Applies a completed move's rotation to the internal cubeState transforms
    /// This permanently updates the transforms and face colors.
    func apply(move: Move) {
        // Rotate the layer's transforms and recolor faces accordingly.
        // We rotate the 9 cubies on the specified layer around the axis by ±90°.
        // Layers: 0..2, axis: x,y,z
        // Rotation matrix for 90 degrees clockwise or counterclockwise.
        let angle = move.anglePerStep * move.direction.rawValue
        let rotation = simd_float4x4(rotationAbout: axisVector(move.axis), angle: angle)
        
        // Identify cubies in the rotating layer
        var newTransforms = transforms
        var newFaceColors = faceColors
        
        for i in 0..<27 {
            let pos = CubeState.cubePositions[i]
            let layerIndex: Int
            switch move.axis {
            case .x: layerIndex = pos.x
            case .y: layerIndex = pos.y
            case .z: layerIndex = pos.z
            }
            if layerIndex == move.layer {
                // Rotate position vector about axis center (cube center is at (1,1,1))
                let posf = SIMD3<Float>(Float(pos.x), Float(pos.y), Float(pos.z))
                let centeredPos = posf - SIMD3<Float>(1,1,1)
                let rotatedCenteredPos4 = (rotation * SIMD4<Float>(centeredPos, 1))
                let rotatedCenteredPos = SIMD3<Float>(rotatedCenteredPos4.x, rotatedCenteredPos4.y, rotatedCenteredPos4.z)
                let rotatedPos = rotatedCenteredPos + SIMD3<Float>(1,1,1)
                
                // Find closest integer position after rotation
                let roundedPos = SIMD3<Int>(Int(round(rotatedPos.x)), Int(round(rotatedPos.y)), Int(round(rotatedPos.z)))
                
                // Find index of cubie at rotated position
                if let destIndex = CubeState.cubePositions.firstIndex(where: { $0 == roundedPos }) {
                    // Rotate transform accordingly
                    let oldTransform = transforms[i]
                    // Remove translation, apply rotation, then translate back
                    let translation = simd_float4x4(translation: -SIMD3<Float>(Float(pos.x) - 1, Float(pos.y) - 1, Float(pos.z) - 1))
                    let invTranslation = simd_float4x4(translation: SIMD3<Float>(Float(roundedPos.x) - 1, Float(roundedPos.y) - 1, Float(roundedPos.z) - 1))
                    let newTransform = invTranslation * rotation * translation * oldTransform
                    newTransforms[destIndex] = newTransform
                    
                    // Rotate face colors for cubie (simulate face color rotation)
                    newFaceColors[destIndex] = rotateFaceColors(faceColors[i], axis: move.axis, direction: move.direction)
                }
            }
        }
        
        print("After move: \(move)")
        for i in 0..<27 {
            let pos = CubeState.cubePositions[i]
            let layerIndex: Int
            switch move.axis {
            case .x: layerIndex = pos.x
            case .y: layerIndex = pos.y
            case .z: layerIndex = pos.z
            }
            if layerIndex == move.layer {
                print("Cubie at \(pos): faceColors=", newFaceColors[i].map { String(format: "[%.2f %.2f %.2f]", $0.x, $0.y, $0.z) })
            }
        }
        
        transforms = newTransforms
        faceColors = newFaceColors
    }
    
    /// Rotates the 6 face colors of a cubie according to the axis and direction of rotation
    private func rotateFaceColors(_ colors: [SIMD3<Float>], axis: Move.Axis, direction: Move.Direction) -> [SIMD3<Float>] {
        // Faces order: +X, -X, +Y, -Y, +Z, -Z
        // CLOCKWISE means from outside looking at that face.
        var newColors = Array(repeating: SIMD3<Float>(0,0,0), count: 6)
        switch axis {
        case .x:
            if direction == .clockwise {
                // +Y->+Z, +Z->-Y, -Y->-Z, -Z->+Y
                newColors[0] = colors[0] // +X stays
                newColors[1] = colors[1] // -X stays
                newColors[2] = colors[4]
                newColors[3] = colors[5]
                newColors[4] = colors[3]
                newColors[5] = colors[2]
            } else {
                newColors[0] = colors[0]
                newColors[1] = colors[1]
                newColors[2] = colors[5]
                newColors[3] = colors[4]
                newColors[4] = colors[2]
                newColors[5] = colors[3]
            }
        case .y:
            if direction == .clockwise {
                // +Z->+X, +X->-Z, -Z->-X, -X->+Z (looking from above)
                newColors[0] = colors[4]
                newColors[1] = colors[5]
                newColors[2] = colors[2]
                newColors[3] = colors[3]
                newColors[4] = colors[1]
                newColors[5] = colors[0]
            } else {
                newColors[0] = colors[5]
                newColors[1] = colors[4]
                newColors[2] = colors[2]
                newColors[3] = colors[3]
                newColors[4] = colors[0]
                newColors[5] = colors[1]
            }
        case .z:
            if direction == .clockwise {
                // +X->+Y, +Y->-X, -X->-Y, -Y->+X (looking from front)
                newColors[0] = colors[2]
                newColors[1] = colors[3]
                newColors[2] = colors[1]
                newColors[3] = colors[0]
                newColors[4] = colors[4]
                newColors[5] = colors[5]
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
        case .x: return SIMD3<Float>(1,0,0)
        case .y: return SIMD3<Float>(0,1,0)
        case .z: return SIMD3<Float>(0,0,1)
        }
    }
}

