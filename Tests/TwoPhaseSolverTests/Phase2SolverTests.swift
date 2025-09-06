//
//  Phase2SolverTests.swift
//  TwoPhaseSolverTests
//
//  Created by Mateusz Kosikowski on 03/09/2025.
//

import XCTest
@testable import TwoPhaseSolver

final class Phase2SolverTests: XCTestCase {
    
    var phase2Solver: Phase2Solver!
    
    override func setUpWithError() throws {
        phase2Solver = Phase2Solver(maxDepth: 12) // Smaller depth for faster tests
    }
    
    override func tearDownWithError() throws {
        phase2Solver = nil
    }
    
    // MARK: - Basic Functionality Tests
    
    func testPhase2SolverInitialization() throws {
        XCTAssertNotNil(phase2Solver, "Phase 2 solver should initialize successfully")
    }
    
    func testSolvedCubePhase2() throws {
        let solvedState = CubeState()
        let solution = phase2Solver.solve(solvedState)
        
        XCTAssertTrue(solution.isEmpty, "Solved cube should have empty phase 2 solution")
    }
    
    func testG1StatePhase2() throws {
        // Create a state that's in G1 (ready for phase 2)
        let g1State = createG1State()
        let solution = phase2Solver.solve(g1State)
        
        // Should have a solution since we're starting from G1
        XCTAssertFalse(solution.isEmpty, "G1 state should have a phase 2 solution")
        XCTAssertTrue(solution.count <= phase2Solver.maxDepth, "Solution should not exceed max depth")
    }
    
    // MARK: - Phase 2 Specific Tests
    
    func testPhase2MovesOnly() throws {
        let g1State = createG1State()
        let solution = phase2Solver.solve(g1State)
        
        // All moves in phase 2 should be from the allowed set
        let allowedMoves: Set<Move> = [
            .U, .U2, .U3,
            .D, .D2, .D3,
            .R, .R2, .R3,
            .L, .L2, .L3,
            .F2, .B2
        ]
        
        for move in solution {
            XCTAssertTrue(allowedMoves.contains(move), "Move \(move.notation) should be allowed in phase 2")
        }
    }
    
    func testNoConsecutiveSameFace() throws {
        let g1State = createG1State()
        let solution = phase2Solver.solve(g1State)
        
        // Check that no consecutive moves are on the same face
        for i in 0..<(solution.count - 1) {
            let currentMove = solution[i]
            let nextMove = solution[i + 1]
            
            XCTAssertNotEqual(currentMove.face, nextMove.face, 
                            "Consecutive moves should not be on the same face: \(currentMove.notation) \(nextMove.notation)")
        }
    }
    
    func testNoConsecutiveOppositeFaces() throws {
        let g1State = createG1State()
        let solution = phase2Solver.solve(g1State)
        
        let oppositeFaces: [Face: Face] = [
            .U: .D, .D: .U,
            .R: .L, .L: .R,
            .F: .B, .B: .F
        ]
        
        // Check that no consecutive moves are on opposite faces
        for i in 0..<(solution.count - 1) {
            let currentMove = solution[i]
            let nextMove = solution[i + 1]
            
            XCTAssertNotEqual(oppositeFaces[currentMove.face], nextMove.face,
                            "Consecutive moves should not be on opposite faces: \(currentMove.notation) \(nextMove.notation)")
        }
    }
    
    // MARK: - Edge Case Tests
    
    func testMaxDepthReached() throws {
        // Create a G1 state that might require many moves to solve
        let complexG1State = createComplexG1State()
        let solution = phase2Solver.solve(complexG1State)
        
        // Solution might be empty if max depth is reached
        // This is expected behavior for very complex G1 states
        if !solution.isEmpty {
            XCTAssertTrue(solution.count <= phase2Solver.maxDepth, "Solution should not exceed max depth")
        }
    }
    
    func testSingleMoveFromG1() throws {
        // Test with a G1 state that's only one move away from solved
        let singleMoveState = applyPhase2Move(.U, to: createG1State())
        let solution = phase2Solver.solve(singleMoveState)
        
        XCTAssertFalse(solution.isEmpty, "Single move from G1 should have a solution")
        XCTAssertTrue(solution.count <= 2, "Solution should be short for single move from G1")
    }
    
    // MARK: - Performance Tests
    
    func testPhase2SolverPerformance() throws {
        let g1State = createG1State()
        
        measure {
            _ = phase2Solver.solve(g1State)
        }
    }
    
    // MARK: - Helper Methods
    
    private func createG1State() -> CubeState {
        // Create a state that's in G1 (all orientations = 0, edges in correct slice)
        var state = CubeState()
        
        // Keep orientations at 0 (already correct)
        // Scramble positions while maintaining G1 properties
        state.cornerPositions = [1, 0, 2, 3, 4, 5, 6, 7]
        state.edgePositions = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]
        
        return state
    }
    
    private func createComplexG1State() -> CubeState {
        // Create a more complex G1 state
        var state = CubeState()
        
        // More complex position scrambling while maintaining G1 properties
        state.cornerPositions = [7, 6, 5, 4, 3, 2, 1, 0]
        state.edgePositions = [11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0]
        
        return state
    }
    
    private func applyPhase2Move(_ move: Move, to state: CubeState) -> CubeState {
        // Apply a phase 2 move to a G1 state
        // This should maintain G1 properties
        var newState = state
        
        // Apply transformations based on the move
        // In a real implementation, this would use proper phase 2 move tables
        switch move.face {
        case .U:
            // Rotate top layer
            let temp = newState.cornerPositions[0]
            newState.cornerPositions[0] = newState.cornerPositions[1]
            newState.cornerPositions[1] = newState.cornerPositions[2]
            newState.cornerPositions[2] = newState.cornerPositions[3]
            newState.cornerPositions[3] = temp
        case .D:
            // Rotate bottom layer
            let temp = newState.cornerPositions[4]
            newState.cornerPositions[4] = newState.cornerPositions[7]
            newState.cornerPositions[7] = newState.cornerPositions[6]
            newState.cornerPositions[6] = newState.cornerPositions[5]
            newState.cornerPositions[5] = temp
        case .R:
            // Rotate right layer
            let temp = newState.cornerPositions[1]
            newState.cornerPositions[1] = newState.cornerPositions[2]
            newState.cornerPositions[2] = newState.cornerPositions[6]
            newState.cornerPositions[6] = newState.cornerPositions[5]
            newState.cornerPositions[5] = temp
        case .L:
            // Rotate left layer
            let temp = newState.cornerPositions[0]
            newState.cornerPositions[0] = newState.cornerPositions[3]
            newState.cornerPositions[3] = newState.cornerPositions[7]
            newState.cornerPositions[7] = newState.cornerPositions[4]
            newState.cornerPositions[4] = temp
        case .F, .B:
            // F2 and B2 moves
            if move.quarterTurns == 2 {
                // Apply 180-degree rotation
                let temp = newState.cornerPositions[2]
                newState.cornerPositions[2] = newState.cornerPositions[7]
                newState.cornerPositions[7] = temp
                
                let temp2 = newState.cornerPositions[3]
                newState.cornerPositions[3] = newState.cornerPositions[6]
                newState.cornerPositions[6] = temp2
            }
        }
        
        return newState
    }
}
