//
//  ContentView.swift
//  RubicCube
//
//  Created by Mateusz Kosikowski on 05/07/2025.
//

import SwiftUI

public struct ContentView: View {
    @StateObject var viewModel = RubiksCubeViewModel()

    public init() {}

    public var body: some View {
        VStack {
            RubiksCubeMetalView(viewModel: viewModel)
                .frame(minHeight: 400)

            HStack(spacing: 16) {
                ForEach(viewModel.allMoves, id: \.self) { move in
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
