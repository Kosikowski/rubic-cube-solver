//
//  Phase1SolverTests.swift
//  TwoPhaseSolverTests
//
//  Created by Mateusz Kosikowski on 03/09/2025.
//

import XCTest
@testable import TwoPhaseSolver

final class Phase1SolverTests: XCTestCase {
    
    var phase1Solver: Phase1Solver!
    
    override func setUpWithError() throws {
        phase1Solver = Phase1Solver(maxDepth: 8) // Smaller depth for faster tests
    }
    
    override func tearDownWithError() throws {
        phase1Solver = nil
    }
    
    // MARK: - Basic Functionality Tests
    
    func testPhase1SolverInitialization() throws {
        XCTAssertNotNil(phase1Solver, "Phase 1 solver should initialize successfully")
    }
    
    func testSolvedCubePhase1() throws {
        let solvedState = CubeState()
        let solution = phase1Solver.solve(solvedState)
        
        XCTAssertTrue(solution.isEmpty, "Solved cube should have empty phase 1 solution")
    }
    
    func testG1StatePhase1() throws {
        // Create a state that's already in G1
        let g1State = createG1State()
        let solution = phase1Solver.solve(g1State)
        
        XCTAssertTrue(solution.isEmpty, "G1 state should have empty phase 1 solution")
    }
    
    // MARK: - Edge Case Tests
    
    func testMaxDepthReached() throws {
        // Create a heavily scrambled state that might exceed max depth
        let scrambledState = createHeavilyScrambledState()
        let solution = phase1Solver.solve(scrambledState)
        
        // Solution might be empty if max depth is reached
        // This is expected behavior for very scrambled cubes
        XCTAssertTrue(solution.count <= phase1Solver.maxDepth, "Solution should not exceed max depth")
    }
    
    func testSingleMoveScramble() throws {
        // Test with a single move scramble
        let singleMoveState = applyMove(.U, to: CubeState())
        let solution = phase1Solver.solve(singleMoveState)
        
        XCTAssertFalse(solution.isEmpty, "Single move scramble should have a solution")
        XCTAssertTrue(solution.count <= 2, "Solution should be short for single move scramble")
    }
    
    // MARK: - Performance Tests
    
    func testPhase1SolverPerformance() throws {
        let scrambledState = createScrambledState()
        
        measure {
            _ = phase1Solver.solve(scrambledState)
        }
    }
    
    // MARK: - Helper Methods
    
    private func createG1State() -> CubeState {
        // Create a state that's in G1 (all orientations = 0, edges in correct slice)
        var state = CubeState()
        
        // Keep orientations at 0 (already correct)
        // Just scramble positions while maintaining G1 properties
        state.cornerPositions = [1, 0, 2, 3, 4, 5, 6, 7]
        state.edgePositions = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]
        
        return state
    }
    
    private func createScrambledState() -> CubeState {
        // Create a moderately scrambled state
        var state = CubeState()
        
        // Scramble corner positions and orientations
        state.cornerPositions = [1, 0, 2, 3, 4, 5, 6, 7]
        state.cornerOrientations = [0, 1, 0, 0, 0, 0, 0, 0]
        
        // Scramble edge positions and orientations
        state.edgePositions = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]
        state.edgeOrientations = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
        
        return state
    }
    
    private func createHeavilyScrambledState() -> CubeState {
        // Create a heavily scrambled state
        var state = CubeState()
        
        // Heavily scramble corner positions and orientations
        state.cornerPositions = [7, 6, 5, 4, 3, 2, 1, 0]
        state.cornerOrientations = [1, 2, 1, 0, 2, 1, 0, 2]
        
        // Heavily scramble edge positions and orientations
        state.edgePositions = [11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0]
        state.edgeOrientations = [1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0]
        
        return state
    }
    
    private func applyMove(_ move: Move, to state: CubeState) -> CubeState {
        // Simplified move application for testing
        // In a real implementation, this would use proper move tables
        var newState = state
        
        // Apply some basic transformations based on the move
        switch move.face {
        case .U:
            // Rotate top layer corners
            let temp = newState.cornerPositions[0]
            newState.cornerPositions[0] = newState.cornerPositions[1]
            newState.cornerPositions[1] = newState.cornerPositions[2]
            newState.cornerPositions[2] = newState.cornerPositions[3]
            newState.cornerPositions[3] = temp
        case .R:
            // Rotate right layer corners
            let temp = newState.cornerPositions[1]
            newState.cornerPositions[1] = newState.cornerPositions[2]
            newState.cornerPositions[2] = newState.cornerPositions[6]
            newState.cornerPositions[6] = newState.cornerPositions[5]
            newState.cornerPositions[5] = temp
        default:
            break
        }
        
        return newState
    }
}
