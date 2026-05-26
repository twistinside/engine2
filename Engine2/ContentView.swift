//
//  ContentView.swift
//  Engine2
//
//  Created by Karl Groff on 3/8/26.
//

import SwiftUI

struct ContentView: View {
    let gameState: Game.State

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            MetalSceneView()
                .ignoresSafeArea()

            Text(gameState.isRunning ? "Simulation Running" : "Simulation Paused")
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))
                .padding()
        }
    }
}
