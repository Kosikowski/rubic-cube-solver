//
//  Phase1Solver.swift
//  TwoPhaseSolver
//
//  Created by Mateusz Kosikowski on 07/07/2025.
//

import Foundation

/// Phase 1 of the 2-phase algorithm
/// Goal: Get the cube into G1 (all corner orientations = 0, all edge orientations = 0, edges in correct slice)
public class Phase1Solver {
    
    /// Maximum depth for phase 1 search
    private let maxDepth: Int
    
    /// Pruning tables for phase 1
    private var cornerOrientationPruning: [Int: Int] = [:]
    private var edgeOrientationPruning: [Int: Int] = [:]
    private var slicePruning: [Int: Int] = [:]
    
    public init(maxDepth: Int = 12) {
        self.maxDepth = maxDepth
        initializePruningTables()
    }
    
    /// Solve phase 1 and return the sequence of moves
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
            return state.isInG1
        }
        
        // Pruning check
        if !isPruned(state, depth: depth) {
            return false
        }
        
        // Try all possible moves
        for move in Move.allCases {
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
        let cornerOrientDist = getCornerOrientationDistance(state)
        let edgeOrientDist = getEdgeOrientationDistance(state)
        let sliceDist = getSliceDistance(state)
        
        return cornerOrientDist <= depth &&
               edgeOrientDist <= depth &&
               sliceDist <= depth
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
        // Initialize corner orientation pruning table
        initializeCornerOrientationPruning()
        
        // Initialize edge orientation pruning table
        initializeEdgeOrientationPruning()
        
        // Initialize slice pruning table
        initializeSlicePruning()
    }
    
    private func initializeCornerOrientationPruning() {
        // BFS from solved state to build pruning table
        var queue: [(CubeState, Int)] = [(CubeState(), 0)]
        var visited: Set<Int> = []
        
        while !queue.isEmpty {
            let (state, distance) = queue.removeFirst()
            let key = getCornerOrientationKey(state)
            
            if visited.contains(key) {
                continue
            }
            visited.insert(key)
            cornerOrientationPruning[key] = distance
            
            // Add all possible moves
            for move in Move.allCases {
                let newState = applyMove(move, to: state)
                let newKey = getCornerOrientationKey(newState)
                if !visited.contains(newKey) {
                    queue.append((newState, distance + 1))
                }
            }
        }
    }
    
    private func initializeEdgeOrientationPruning() {
        // Similar BFS for edge orientations
        // Implementation would be similar to corner orientation
    }
    
    private func initializeSlicePruning() {
        // Similar BFS for slice positions
        // Implementation would be similar to corner orientation
    }
    
    // MARK: - Distance Functions
    
    private func getCornerOrientationDistance(_ state: CubeState) -> Int {
        let key = getCornerOrientationKey(state)
        return cornerOrientationPruning[key] ?? Int.max
    }
    
    private func getEdgeOrientationDistance(_ state: CubeState) -> Int {
        let key = getEdgeOrientationKey(state)
        return edgeOrientationPruning[key] ?? Int.max
    }
    
    private func getSliceDistance(_ state: CubeState) -> Int {
        let key = getSliceKey(state)
        return slicePruning[key] ?? Int.max
    }
    
    // MARK: - Key Generation
    
    private func getCornerOrientationKey(_ state: CubeState) -> Int {
        // Convert corner orientations to a unique key
        var key = 0
        for i in 0..<7 { // Last corner orientation is determined by the others
            key = key * 3 + state.cornerOrientations[i]
        }
        return key
    }
    
    private func getEdgeOrientationKey(_ state: CubeState) -> Int {
        // Convert edge orientations to a unique key
        var key = 0
        for i in 0..<11 { // Last edge orientation is determined by the others
            key = key * 2 + state.edgeOrientations[i]
        }
        return key
    }
    
    private func getSliceKey(_ state: CubeState) -> Int {
        // Convert slice positions to a unique key
        // This is more complex and would involve tracking which edges are in which slice
        return 0 // Simplified
    }
}
