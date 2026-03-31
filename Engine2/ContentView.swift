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
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text(gameState.isRunning ? "Simulation Running" : "Simulation Paused")
        }
        .padding()
    }
}
