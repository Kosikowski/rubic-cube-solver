//
//  TwoPhaseSolver.swift
//  TwoPhaseSolver
//
//  Created by Mateusz Kosikowski on 07/07/2025.
//

import Foundation

/// Main 2-phase Rubik's Cube solver
/// Implements the classic 2-phase algorithm for optimal cube solving
public class TwoPhaseSolver {
    
    private let phase1Solver: Phase1Solver
    private let phase2Solver: Phase2Solver
    
    public init(phase1MaxDepth: Int = 12, phase2MaxDepth: Int = 18) {
        self.phase1Solver = Phase1Solver(maxDepth: phase1MaxDepth)
        self.phase2Solver = Phase2Solver(maxDepth: phase2MaxDepth)
    }
    
    /// Solve a scrambled cube and return the complete solution
    /// - Parameter cubeState: The scrambled cube state
    /// - Returns: Array of moves that solve the cube, or empty array if no solution found
    public func solve(_ cubeState: CubeState) -> [Move] {
        // Phase 1: Get cube into G1
        let phase1Solution = phase1Solver.solve(cubeState)
        
        if phase1Solution.isEmpty {
            return [] // No phase 1 solution found
        }
        
        // Apply phase 1 moves to get to G1
        var g1State = cubeState
        for move in phase1Solution {
            g1State = applyMove(move, to: g1State)
        }
        
        // Phase 2: Solve from G1 to solved state
        let phase2Solution = phase2Solver.solve(g1State)
        
        if phase2Solution.isEmpty {
            return [] // No phase 2 solution found
        }
        
        // Combine both phases
        return phase1Solution + phase2Solution
    }
    
    /// Solve with detailed information about each phase
    /// - Parameter cubeState: The scrambled cube state
    /// - Returns: Detailed solution information
    public func solveDetailed(_ cubeState: CubeState) -> TwoPhaseSolution {
        let startTime = Date()
        
        // Phase 1
        let phase1StartTime = Date()
        let phase1Solution = phase1Solver.solve(cubeState)
        let phase1Time = Date().timeIntervalSince(phase1StartTime)
        
        if phase1Solution.isEmpty {
            return TwoPhaseSolution(
                phase1Moves: [],
                phase2Moves: [],
                totalMoves: 0,
                phase1Time: phase1Time,
                phase2Time: 0,
                totalTime: Date().timeIntervalSince(startTime),
                success: false
            )
        }
        
        // Apply phase 1 moves
        var g1State = cubeState
        for move in phase1Solution {
            g1State = applyMove(move, to: g1State)
        }
        
        // Phase 2
        let phase2StartTime = Date()
        let phase2Solution = phase2Solver.solve(g1State)
        let phase2Time = Date().timeIntervalSince(phase2StartTime)
        
        let totalTime = Date().timeIntervalSince(startTime)
        
        return TwoPhaseSolution(
            phase1Moves: phase1Solution,
            phase2Moves: phase2Solution,
            totalMoves: phase1Solution.count + phase2Solution.count,
            phase1Time: phase1Time,
            phase2Time: phase2Time,
            totalTime: totalTime,
            success: !phase2Solution.isEmpty
        )
    }
    
    /// Apply a move to a cube state
    private func applyMove(_ move: Move, to state: CubeState) -> CubeState {
        // This is a simplified implementation
        // In a real implementation, you would have lookup tables for each move
        var newState = state
        
        // Apply corner position and orientation changes
        // Apply edge position and orientation changes
        
        return newState
    }
}

/// Detailed solution information from the 2-phase solver
public struct TwoPhaseSolution {
    public let phase1Moves: [Move]
    public let phase2Moves: [Move]
    public let totalMoves: Int
    public let phase1Time: TimeInterval
    public let phase2Time: TimeInterval
    public let totalTime: TimeInterval
    public let success: Bool
    
    /// Complete solution as a single array of moves
    public var allMoves: [Move] {
        return phase1Moves + phase2Moves
    }
    
    /// Solution as a string notation
    public var notation: String {
        return allMoves.map { $0.notation }.joined(separator: " ")
    }
    
    /// Phase 1 solution as a string notation
    public var phase1Notation: String {
        return phase1Moves.map { $0.notation }.joined(separator: " ")
    }
    
    /// Phase 2 solution as a string notation
    public var phase2Notation: String {
        return phase2Moves.map { $0.notation }.joined(separator: " ")
    }
}
