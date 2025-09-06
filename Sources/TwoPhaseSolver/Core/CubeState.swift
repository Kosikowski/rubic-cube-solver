//
//  CubeState.swift
//  TwoPhaseSolver
//
//  Created by Mateusz Kosikowski on 07/07/2025.
//

import Foundation

/// Represents the state of a Rubik's Cube for the 2-phase solving algorithm
public struct CubeState {
    /// Corner positions (0-7)
    public var cornerPositions: [Int]
    /// Corner orientations (0-2 for each corner)
    public var cornerOrientations: [Int]
    /// Edge positions (0-11)
    public var edgePositions: [Int]
    /// Edge orientations (0-1 for each edge)
    public var edgeOrientations: [Int]
    
    /// Initialize with solved state
    public init() {
        cornerPositions = Array(0..<8)
        cornerOrientations = Array(repeating: 0, count: 8)
        edgePositions = Array(0..<12)
        edgeOrientations = Array(repeating: 0, count: 12)
    }
    
    /// Initialize with specific state
    public init(cornerPositions: [Int], cornerOrientations: [Int], 
                edgePositions: [Int], edgeOrientations: [Int]) {
        self.cornerPositions = cornerPositions
        self.cornerOrientations = cornerOrientations
        self.edgePositions = edgePositions
        self.edgeOrientations = edgeOrientations
    }
    
    /// Check if the cube is in a solved state
    public var isSolved: Bool {
        return cornerPositions == Array(0..<8) &&
               cornerOrientations.allSatisfy { $0 == 0 } &&
               edgePositions == Array(0..<12) &&
               edgeOrientations.allSatisfy { $0 == 0 }
    }
    
    /// Check if the cube is in G1 (after phase 1)
    public var isInG1: Bool {
        // All corner orientations are 0
        // All edge orientations are 0
        // Edge positions are in their correct slice (0-3, 4-7, 8-11)
        return cornerOrientations.allSatisfy { $0 == 0 } &&
               edgeOrientations.allSatisfy { $0 == 0 } &&
               isEdgesInCorrectSlice
    }
    
    private var isEdgesInCorrectSlice: Bool {
        // Check if edges are in their correct slice positions
        let slice1 = Set(0..<4)  // UD slice
        let slice2 = Set(4..<8)  // RL slice  
        let slice3 = Set(8..<12) // FB slice
        
        let currentSlice1 = Set(edgePositions[0..<4])
        let currentSlice2 = Set(edgePositions[4..<8])
        let currentSlice3 = Set(edgePositions[8..<12])
        
        return currentSlice1.isSubset(of: slice1) &&
               currentSlice2.isSubset(of: slice2) &&
               currentSlice3.isSubset(of: slice3)
    }
}
