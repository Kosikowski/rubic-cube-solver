//
//  ContentView.swift
//  RubicCube
//
//  Created by Mateusz Kosikowski on 05/07/2025.
//

import SwiftUI

struct ContentView: View {
    @StateObject var viewModel = RubiksCubeViewModel()
    
    enum UserMove: String, CaseIterable {
        case U, R, L, F, B, D, H, V
        
        var displayName: String {
            self.rawValue.uppercased()
        }
        func move() -> Move? {
            switch self {
            case .U: return Move(axis: .y, layer: 2, direction: .clockwise)
            case .D: return Move(axis: .y, layer: 0, direction: .clockwise)
            case .L: return Move(axis: .x, layer: 0, direction: .clockwise)
            case .R: return Move(axis: .x, layer: 2, direction: .clockwise)
            case .F: return Move(axis: .z, layer: 2, direction: .clockwise)
            case .B: return Move(axis: .z, layer: 0, direction: .clockwise)
            case .H: return Move(axis: .y, layer: 1, direction: .clockwise)
            case .V: return Move(axis: .x, layer: 1, direction: .clockwise)
            
            }
        }
    }
    
    
    var body: some View {
        VStack {
            RubiksCubeMetalView(viewModel: viewModel)
                .frame(minHeight: 400)
            
            HStack(spacing: 16) {
                ForEach(UserMove.allCases, id: \.self) { move in
                    Button(move.rawValue) {
                        if let moveObj = move.move() {
                            viewModel.enqueue(move: moveObj)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(.top)
            
            HStack(spacing: 16) {
                Button("Scramble") {
                    viewModel.scramble()
                }
                .buttonStyle(.bordered)
                
                Button("Reset") {
                    viewModel.solve()
                }
                .buttonStyle(.bordered)
            }
            .padding(.top)
        }
        .padding()
    }
}

