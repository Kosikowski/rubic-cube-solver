//
//  Move.swift
//  RubicCube
//
//  Created by Mateusz Kosikowski on 07/07/2025.
//
// This file contains types and logic for representing individual Rubik's Cube moves.
//

import Foundation

/// Custom operator to check if two moves are inverse and cancel each other.
infix operator <~>: AdditionPrecedence

/// Model representing a single move on a Rubik's Cube.
/// Encapsulates the axis, layer, direction, and animation details of the move.
struct Move: Equatable {
    /// Axis of rotation for the move.
    enum Axis {
        case x, y, z
    }

    /// Direction of the rotation as seen from the face being turned.
    enum Direction: Float {
        /// Clockwise rotation
        case clockwise = 1
        /// Counterclockwise rotation
        case counterClockwise = -1
    }

    /// The axis around which the move rotates.
    /// X, Y or Z axis of the cube.
    let axis: Axis

    /// The index of the layer being turned (0 = left/bottom/back, 2 = right/top/front).
    let layer: Int

    /// The direction of the rotation (clockwise or counterclockwise) as viewed from the rotated face.
    let direction: Direction

    /// The angle (in radians) for one move step; always 90 degrees (π/2).
    let anglePerStep: Float = .pi / 2

    /// The standard duration (in seconds) to animate a single move.
    let duration: TimeInterval = 0.35

    /// Multiplier to produce a signed rotation angle following cube notation conventions.
    /// +1 or -1 so that `.clockwise` always corresponds to a clockwise rotation
    /// when looking straight at the face being turned.
    var signedAngleMultiplier: Float {
        // baseSign: +1 for clockwise, -1 for counterclockwise (standard cube notation)
        let baseSign: Float = (direction == .clockwise) ? +1 : -1

        // For layer 0 (left, bottom, back faces), the sign is inverted to maintain correct orientation.
        switch axis {
        case .x: return layer == 0 ? -baseSign : baseSign
        case .y: return layer == 0 ? -baseSign : baseSign
        case .z: return layer == 0 ? -baseSign : baseSign
        }
    }

    /// Checks whether two moves are inverse of each other, i.e., they cancel each other out.
    /// Returns true if both moves affect the same axis and layer, but have opposite directions.
    static func <~> (lhs: Move, rhs: Move) -> Bool {
        return lhs.axis == rhs.axis && lhs.layer == rhs.layer && lhs.direction != rhs.direction
    }
}
