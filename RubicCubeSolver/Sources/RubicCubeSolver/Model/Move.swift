//
//  Move.swift
//  RubicCube
//
//  Created by Mateusz Kosikowski on 07/07/2025.
//
import Foundation

/// Represents a single Rubik's Cube move.
struct Move {
    enum Axis {
        case x, y, z
    }

    enum Direction: Float {
        case clockwise = 1
        case counterClockwise = -1
    }

    let axis: Axis
    let layer: Int // 0..2 for layer index on axis
    let direction: Direction
    let anglePerStep: Float = .pi / 2 // 90 degrees

    /// Total animation duration
    let duration: TimeInterval = 0.25

    /// +1 or –1 so that `.clockwise` is always clockwise
    /// when you look straight at the face being turned.
    var signedAngleMultiplier: Float {
        // baseSign:  +1 for CW, –1 for CCW (standard cube notation)
        let baseSign: Float = (direction == .clockwise) ? +1 : -1

        switch axis {
        case .x: return layer == 0 ? -baseSign : baseSign // L face flips
        case .y: return layer == 0 ? -baseSign : baseSign // D face flips
        case .z: return layer == 0 ? -baseSign : baseSign // B face flips
        }
    }
}
