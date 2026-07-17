//
//  ContentView.swift
//  Engine2
//
//  Created by Karl Groff on 3/8/26.
//

import SwiftUI

struct ContentView: View {
    let simulation: SimulationRuntime
    let debugOptions: AppDebugOptions
    let renderAssetCatalog: RenderAssetCatalog

    var body: some View {
        ZStack {
            MetalSceneView(renderAssetCatalog: renderAssetCatalog) {
                RenderFrame.extract(from: simulation.world)
            } inputHandler: { event in
                simulation.handleInput(event)
            }
                .ignoresSafeArea()

            Button {
                toggleSimulation()
            } label: {
                Label(
                    simulation.state.isRunning ? "Simulation Running" : "Simulation Paused",
                    systemImage: simulation.state.isRunning ? "pause.fill" : "play.fill"
                )
                .font(.caption)
            }
                .buttonStyle(.glass)
                .controlSize(.small)
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)

            if debugOptions.showsInputHistory {
                InputHistoryPane(simulation: simulation)
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
    }

    private func toggleSimulation() {
        if simulation.state.isRunning {
            simulation.pauseSimulation()
        } else {
            simulation.resumeSimulation()
        }
    }
}
