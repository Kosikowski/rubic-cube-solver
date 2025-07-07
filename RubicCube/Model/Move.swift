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
    let layer: Int  // 0..2 for layer index on axis
    let direction: Direction
    let anglePerStep: Float = Float.pi / 2  // 90 degrees
    
    /// Total animation duration
    let duration: TimeInterval = 0.25
}
