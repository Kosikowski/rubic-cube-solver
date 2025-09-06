//
//  Phase2Solver.swift
//  TwoPhaseSolver
//
//  Created by Mateusz Kosikowski on 07/07/2025.
//

import Foundation

/// Phase 2 of the 2-phase algorithm
/// Goal: Solve the cube completely (all pieces in correct positions and orientations)
public class Phase2Solver {
    
    /// Maximum depth for phase 2 search
    private let maxDepth: Int
    
    /// Pruning tables for phase 2
    private var cornerPositionPruning: [Int: Int] = [:]
    private var edgePositionPruning: [Int: Int] = [:]
    private var cornerPermutationPruning: [Int: Int] = [:]
    private var edgePermutationPruning: [Int: Int] = [:]
    
    /// Allowed moves in phase 2 (only U, D, R, L, F2, B2)
    private let phase2Moves: [Move] = [
        .U, .U2, .U3,
        .D, .D2, .D3,
        .R, .R2, .R3,
        .L, .L2, .L3,
        .F2, .B2
    ]
    
    public init(maxDepth: Int = 18) {
        self.maxDepth = maxDepth
        initializePruningTables()
    }
    
    /// Solve phase 2 and return the sequence of moves
    public func solve(_ cubeState: CubeState) -> [Move] {
        var solution: [Move] = []
        var currentState = cubeState
        
        // Use iterative deepening search
        for depth in 0...maxDepth {
            if search(currentState, depth: depth, solution: &solution, lastMove: nil) {
                return solution
            }
        }
        
        return [] // No solution found within max depth
    }
    
    /// Recursive search with pruning
    private func search(_ state: CubeState, depth: Int, solution: inout [Move], lastMove: Move?) -> Bool {
        if depth == 0 {
            return state.isSolved
        }
        
        // Pruning check
        if !isPruned(state, depth: depth) {
            return false
        }
        
        // Try all phase 2 moves
        for move in phase2Moves {
            // Skip redundant moves
            if shouldSkipMove(move, lastMove: lastMove) {
                continue
            }
            
            let newState = applyMove(move, to: state)
            solution.append(move)
            
            if search(newState, depth: depth - 1, solution: &solution, lastMove: move) {
                return true
            }
            
            solution.removeLast()
        }
        
        return false
    }
    
    /// Check if the current state is pruned (impossible to solve in remaining depth)
    private func isPruned(_ state: CubeState, depth: Int) -> Bool {
        let cornerPosDist = getCornerPositionDistance(state)
        let edgePosDist = getEdgePositionDistance(state)
        let cornerPermDist = getCornerPermutationDistance(state)
        let edgePermDist = getEdgePermutationDistance(state)
        
        return cornerPosDist <= depth &&
               edgePosDist <= depth &&
               cornerPermDist <= depth &&
               edgePermDist <= depth
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
    
    /// Skip redundant moves (same face as last move, or opposite face)
    private func shouldSkipMove(_ move: Move, lastMove: Move?) -> Bool {
        guard let lastMove = lastMove else { return false }
        
        // Don't repeat the same face
        if move.face == lastMove.face {
            return true
        }
        
        // Don't do opposite faces consecutively (e.g., U then D)
        let oppositeFaces: [Face: Face] = [
            .U: .D, .D: .U,
            .R: .L, .L: .R,
            .F: .B, .B: .F
        ]
        
        if oppositeFaces[move.face] == lastMove.face {
            return true
        }
        
        return false
    }
    
    // MARK: - Pruning Table Initialization
    
    private func initializePruningTables() {
        // Initialize corner position pruning table
        initializeCornerPositionPruning()
        
        // Initialize edge position pruning table
        initializeEdgePositionPruning()
        
        // Initialize corner permutation pruning table
        initializeCornerPermutationPruning()
        
        // Initialize edge permutation pruning table
        initializeEdgePermutationPruning()
    }
    
    private func initializeCornerPositionPruning() {
        // BFS from solved state to build pruning table
        var queue: [(CubeState, Int)] = [(CubeState(), 0)]
        var visited: Set<Int> = []
        
        while !queue.isEmpty {
            let (state, distance) = queue.removeFirst()
            let key = getCornerPositionKey(state)
            
            if visited.contains(key) {
                continue
            }
            visited.insert(key)
            cornerPositionPruning[key] = distance
            
            // Add all phase 2 moves
            for move in phase2Moves {
                let newState = applyMove(move, to: state)
                let newKey = getCornerPositionKey(newState)
                if !visited.contains(newKey) {
                    queue.append((newState, distance + 1))
                }
            }
        }
    }
    
    private func initializeEdgePositionPruning() {
        // Similar BFS for edge positions
        // Implementation would be similar to corner position
    }
    
    private func initializeCornerPermutationPruning() {
        // Similar BFS for corner permutations
        // Implementation would be similar to corner position
    }
    
    private func initializeEdgePermutationPruning() {
        // Similar BFS for edge permutations
        // Implementation would be similar to corner position
    }
    
    // MARK: - Distance Functions
    
    private func getCornerPositionDistance(_ state: CubeState) -> Int {
        let key = getCornerPositionKey(state)
        return cornerPositionPruning[key] ?? Int.max
    }
    
    private func getEdgePositionDistance(_ state: CubeState) -> Int {
        let key = getEdgePositionKey(state)
        return edgePositionPruning[key] ?? Int.max
    }
    
    private func getCornerPermutationDistance(_ state: CubeState) -> Int {
        let key = getCornerPermutationKey(state)
        return cornerPermutationPruning[key] ?? Int.max
    }
    
    private func getEdgePermutationDistance(_ state: CubeState) -> Int {
        let key = getEdgePermutationKey(state)
        return edgePermutationPruning[key] ?? Int.max
    }
    
    // MARK: - Key Generation
    
    private func getCornerPositionKey(_ state: CubeState) -> Int {
        // Convert corner positions to a unique key
        var key = 0
        for i in 0..<8 {
            key = key * 8 + state.cornerPositions[i]
        }
        return key
    }
    
    private func getEdgePositionKey(_ state: CubeState) -> Int {
        // Convert edge positions to a unique key
        var key = 0
        for i in 0..<12 {
            key = key * 12 + state.edgePositions[i]
        }
        return key
    }
    
    private func getCornerPermutationKey(_ state: CubeState) -> Int {
        // Convert corner permutation to a unique key
        // This would involve calculating the permutation index
        return 0 // Simplified
    }
    
    private func getEdgePermutationKey(_ state: CubeState) -> Int {
        // Convert edge permutation to a unique key
        // This would involve calculating the permutation index
        return 0 // Simplified
    }
}
