//
//  TwoPhaseSolverTests.swift
//  TwoPhaseSolverTests
//
//  Created by Mateusz Kosikowski on 03/09/2025.
//

import XCTest
@testable import TwoPhaseSolver

final class TwoPhaseSolverTests: XCTestCase {
    
    var solver: TwoPhaseSolver!
    
    override func setUpWithError() throws {
        solver = TwoPhaseSolver()
    }
    
    override func tearDownWithError() throws {
        solver = nil
    }
    
    // MARK: - CubeState Tests
    
    func testSolvedCubeState() throws {
        let solvedState = CubeState()
        
        XCTAssertTrue(solvedState.isSolved, "Solved state should be marked as solved")
        XCTAssertTrue(solvedState.isInG1, "Solved state should be in G1")
        
        // Check corner positions
        XCTAssertEqual(solvedState.cornerPositions, Array(0..<8), "Corner positions should be 0-7")
        
        // Check corner orientations
        XCTAssertTrue(solvedState.cornerOrientations.allSatisfy { $0 == 0 }, "All corner orientations should be 0")
        
        // Check edge positions
        XCTAssertEqual(solvedState.edgePositions, Array(0..<12), "Edge positions should be 0-11")
        
        // Check edge orientations
        XCTAssertTrue(solvedState.edgeOrientations.allSatisfy { $0 == 0 }, "All edge orientations should be 0")
    }
    
    func testCubeStateInitialization() throws {
        let cornerPositions = [1, 0, 2, 3, 4, 5, 6, 7]
        let cornerOrientations = [0, 1, 0, 0, 0, 0, 0, 0]
        let edgePositions = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]
        let edgeOrientations = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
        
        let state = CubeState(
            cornerPositions: cornerPositions,
            cornerOrientations: cornerOrientations,
            edgePositions: edgePositions,
            edgeOrientations: edgeOrientations
        )
        
        XCTAssertEqual(state.cornerPositions, cornerPositions)
        XCTAssertEqual(state.cornerOrientations, cornerOrientations)
        XCTAssertEqual(state.edgePositions, edgePositions)
        XCTAssertEqual(state.edgeOrientations, edgeOrientations)
    }
    
    // MARK: - Move Tests
    
    func testMoveProperties() throws {
        let move = Move.U
        
        XCTAssertEqual(move.face, .U, "Move face should be U")
        XCTAssertEqual(move.quarterTurns, 1, "U move should be 1 quarter turn")
        XCTAssertEqual(move.notation, "U", "U move notation should be 'U'")
        XCTAssertEqual(move.inverse, .U3, "U inverse should be U'")
    }
    
    func testMoveInverses() throws {
        // Test all move inverses
        XCTAssertEqual(Move.U.inverse, .U3)
        XCTAssertEqual(Move.U2.inverse, .U2)
        XCTAssertEqual(Move.U3.inverse, .U)
        
        XCTAssertEqual(Move.R.inverse, .R3)
        XCTAssertEqual(Move.R2.inverse, .R2)
        XCTAssertEqual(Move.R3.inverse, .R)
        
        XCTAssertEqual(Move.F.inverse, .F3)
        XCTAssertEqual(Move.F2.inverse, .F2)
        XCTAssertEqual(Move.F3.inverse, .F)
    }
    
    func testMoveNotation() throws {
        XCTAssertEqual(Move.U.notation, "U")
        XCTAssertEqual(Move.U2.notation, "U2")
        XCTAssertEqual(Move.U3.notation, "U'")
        
        XCTAssertEqual(Move.R.notation, "R")
        XCTAssertEqual(Move.R2.notation, "R2")
        XCTAssertEqual(Move.R3.notation, "R'")
    }
    
    // MARK: - Phase 1 Solver Tests
    
    func testPhase1SolverInitialization() throws {
        let phase1Solver = Phase1Solver(maxDepth: 10)
        XCTAssertNotNil(phase1Solver, "Phase 1 solver should initialize")
    }
    
    func testPhase1SolverWithSolvedCube() throws {
        let phase1Solver = Phase1Solver()
        let solvedState = CubeState()
        
        let solution = phase1Solver.solve(solvedState)
        
        XCTAssertTrue(solution.isEmpty, "Solved cube should have empty phase 1 solution")
    }
    
    // MARK: - Phase 2 Solver Tests
    
    func testPhase2SolverInitialization() throws {
        let phase2Solver = Phase2Solver(maxDepth: 15)
        XCTAssertNotNil(phase2Solver, "Phase 2 solver should initialize")
    }
    
    func testPhase2SolverWithSolvedCube() throws {
        let phase2Solver = Phase2Solver()
        let solvedState = CubeState()
        
        let solution = phase2Solver.solve(solvedState)
        
        XCTAssertTrue(solution.isEmpty, "Solved cube should have empty phase 2 solution")
    }
    
    // MARK: - Two Phase Solver Tests
    
    func testTwoPhaseSolverInitialization() throws {
        let solver = TwoPhaseSolver(phase1MaxDepth: 10, phase2MaxDepth: 15)
        XCTAssertNotNil(solver, "Two phase solver should initialize")
    }
    
    func testTwoPhaseSolverWithSolvedCube() throws {
        let solvedState = CubeState()
        
        let solution = solver.solve(solvedState)
        
        XCTAssertTrue(solution.isEmpty, "Solved cube should have empty solution")
    }
    
    func testTwoPhaseSolverDetailedWithSolvedCube() throws {
        let solvedState = CubeState()
        
        let detailedSolution = solver.solveDetailed(solvedState)
        
        XCTAssertTrue(detailedSolution.success, "Solved cube should have successful solution")
        XCTAssertTrue(detailedSolution.phase1Moves.isEmpty, "Phase 1 should be empty for solved cube")
        XCTAssertTrue(detailedSolution.phase2Moves.isEmpty, "Phase 2 should be empty for solved cube")
        XCTAssertEqual(detailedSolution.totalMoves, 0, "Total moves should be 0 for solved cube")
    }
    
    // MARK: - Solution Tests
    
    func testTwoPhaseSolutionProperties() throws {
        let phase1Moves: [Move] = [.U, .R, .F]
        let phase2Moves: [Move] = [.D, .L, .B]
        
        let solution = TwoPhaseSolution(
            phase1Moves: phase1Moves,
            phase2Moves: phase2Moves,
            totalMoves: 6,
            phase1Time: 0.1,
            phase2Time: 0.2,
            totalTime: 0.3,
            success: true
        )
        
        XCTAssertEqual(solution.allMoves, phase1Moves + phase2Moves, "All moves should combine both phases")
        XCTAssertEqual(solution.notation, "U R F D L B", "Notation should be space-separated moves")
        XCTAssertEqual(solution.phase1Notation, "U R F", "Phase 1 notation should be correct")
        XCTAssertEqual(solution.phase2Notation, "D L B", "Phase 2 notation should be correct")
        XCTAssertTrue(solution.success, "Solution should be marked as successful")
    }
    
    // MARK: - Performance Tests
    
    func testSolverPerformance() throws {
        let scrambledState = createScrambledState()
        
        measure {
            _ = solver.solve(scrambledState)
        }
    }
    
    // MARK: - Helper Methods
    
    private func createScrambledState() -> CubeState {
        // Create a simple scrambled state for testing
        // In a real implementation, this would be more sophisticated
        var state = CubeState()
        
        // Apply some random scrambling
        state.cornerPositions = [1, 0, 2, 3, 4, 5, 6, 7]
        state.cornerOrientations = [0, 1, 0, 0, 0, 0, 0, 0]
        
        return state
    }
}
