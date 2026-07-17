import SwiftUI

/// Root application view that composes rendering and app-level debug controls.
///
/// The view receives runtime capabilities from the App composition root. It
/// does not own simulation truth: the Metal scene consumes immutable
/// presentation snapshots, while controls invoke the Simulation Runtime's
/// explicit lifecycle API.
struct ContentView: View {
    let inputRuntime: InputRuntime
    let simulation: SimulationRuntime
    let debugOptions: AppDebugOptions
    let renderAssetCatalog: RenderAssetCatalog

    var body: some View {
        ZStack {
            MetalSceneView(
                renderAssetCatalog: renderAssetCatalog,
                presentationSource: simulation,
                inputSink: inputRuntime
            )
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
