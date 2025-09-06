//
//  Move.swift
//  TwoPhaseSolver
//
//  Created by Mateusz Kosikowski on 07/07/2025.
//

import Foundation

/// Represents a move in the 2-phase solving algorithm
public enum Move: Int, CaseIterable {
    case U = 0, U2 = 1, U3 = 2
    case R = 3, R2 = 4, R3 = 5
    case F = 6, F2 = 7, F3 = 8
    case D = 9, D2 = 10, D3 = 11
    case L = 12, L2 = 13, L3 = 14
    case B = 15, B2 = 16, B3 = 17
    
    /// Face of the move
    public var face: Face {
        switch self {
        case .U, .U2, .U3: return .U
        case .R, .R2, .R3: return .R
        case .F, .F2, .F3: return .F
        case .D, .D2, .D3: return .D
        case .L, .L2, .L3: return .L
        case .B, .B2, .B3: return .B
        }
    }
    
    /// Number of quarter turns (1, 2, or 3)
    public var quarterTurns: Int {
        switch self {
        case .U, .R, .F, .D, .L, .B: return 1
        case .U2, .R2, .F2, .D2, .L2, .B2: return 2
        case .U3, .R3, .F3, .D3, .L3, .B3: return 3
        }
    }
    
    /// String representation of the move
    public var notation: String {
        switch self {
        case .U, .R, .F, .D, .L, .B: return face.rawValue
        case .U2, .R2, .F2, .D2, .L2, .B2: return face.rawValue + "2"
        case .U3, .R3, .F3, .D3, .L3, .B3: return face.rawValue + "'"
        }
    }
    
    /// Inverse of the move
    public var inverse: Move {
        switch self {
        case .U: return .U3
        case .U2: return .U2
        case .U3: return .U
        case .R: return .R3
        case .R2: return .R2
        case .R3: return .R
        case .F: return .F3
        case .F2: return .F2
        case .F3: return .F
        case .D: return .D3
        case .D2: return .D2
        case .D3: return .D
        case .L: return .L3
        case .L2: return .L2
        case .L3: return .L
        case .B: return .B3
        case .B2: return .B2
        case .B3: return .B
        }
    }
}

/// Face enumeration
public enum Face: String, CaseIterable {
    case U = "U", R = "R", F = "F", D = "D", L = "L", B = "B"
}
