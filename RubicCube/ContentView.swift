//
//  ContentView.swift
//  RubicCube
//
//  Created by Mateusz Kosikowski on 05/07/2025.
//

import SwiftUI

struct ContentView: View {
    @StateObject var viewModel = RubiksCubeViewModel()
    
    let moves = ["U", "R", "L", "F", "B", "D"]
    
    func moveFromString(_ s: String) -> Move? {
        switch s {
        case "U": return Move(axis: .y, layer: 2, direction: .clockwise)
        case "D": return Move(axis: .y, layer: 0, direction: .clockwise)
        case "L": return Move(axis: .x, layer: 0, direction: .clockwise)
        case "R": return Move(axis: .x, layer: 2, direction: .clockwise)
        case "F": return Move(axis: .z, layer: 2, direction: .clockwise)
        case "B": return Move(axis: .z, layer: 0, direction: .clockwise)
        default: return nil
        }
    }
    
    var body: some View {
        VStack {
            RubiksCubeMetalView(viewModel: viewModel)
                .frame(minHeight: 400)
            
            HStack(spacing: 16) {
                ForEach(moves, id: \.self) { move in
                    Button(move) {
                        if let moveObj = moveFromString(move) {
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
                
                Button("Solve") {
                    viewModel.solve()
                }
                .buttonStyle(.bordered)
            }
            .padding(.top)
        }
        .padding()
    }
}

