//
//  Animator.swift
//  RubicCubeSolver
//
//  Created by Mateusz Kosikowski on 08/07/2025.
//
import Foundation
import simd

protocol Animator {
    func start(move: Move) -> Bool
    func update(deltaTime: TimeInterval) -> Move?
    func rotationMatrix() -> simd_float4x4?
    func cubieTransforms(for solver: Solver) -> [simd_float4x4]
    var currentMove: Move? { get }
    var currentAxis: Move.Axis { get }
    var currentLayer: Int { get }
}
