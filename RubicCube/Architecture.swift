//
//  Architecture.swift
//  RubicCube
//
//  Created by Mateusz Kosikowski on 07/07/2025.
//
//
//┌──────────────────┐      ┌──────────────────┐      ┌───────────────────┐
//│  Solver Module   │───►──│  Animation Queue │───►──│    Renderer       │
//│  (CPU – Swift)   │      │  (Swift)         │      │  (GPU – Metal)    │
//└──────────────────┘      └──────────────────┘      └───────────────────┘
//         ▲                          ▲                         ▲
//         │                          │                         │
//         │                          └─── Model (CubeState) ───┘
//         │                                       │
//         └────────── User Input/UI ─────────────┘


//
//function KociembaSolve(startState):
//  // Phase 1
//  threshold ← h₁(startState)
//  loop:
//    result ← IDAStar(startState, 0, threshold, phase=1)
//    if result.found:
//      S₁ ← result.path
//      break
//    threshold ← result.nextMin
//
//  // Apply S₁ to get midState
//  midState ← applyMoves(startState, S₁)
//
//  // Phase 2
//  threshold ← h₂(midState)
//  loop:
//    result ← IDAStar(midState, 0, threshold, phase=2)
//    if result.found:
//      S₂ ← result.path
//      break
//    threshold ← result.nextMin
//
//  return concatenate(S₁, S₂)
