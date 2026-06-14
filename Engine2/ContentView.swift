//
//  ContentView.swift
//  Engine2
//
//  Created by Karl Groff on 3/8/26.
//

import SwiftUI

struct ContentView: View {
    let game: Game

    var body: some View {
        ZStack {
            MetalSceneView {
                RenderFrame.extract(from: game.world)
            } inputHandler: { event in
                game.handleInput(event)
            }
                .ignoresSafeArea()

            Button {
                toggleSimulation()
            } label: {
                Label(
                    game.state.isRunning ? "Simulation Running" : "Simulation Paused",
                    systemImage: game.state.isRunning ? "pause.fill" : "play.fill"
                )
                .font(.caption)
            }
                .buttonStyle(.glass)
                .controlSize(.small)
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)

            InputHistoryPane(game: game)
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        }
    }

    private func toggleSimulation() {
        if game.state.isRunning {
            game.pauseSimulation()
        } else {
            game.resumeSimulation()
        }
    }
}
