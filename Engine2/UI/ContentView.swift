import SwiftUI

/// Root application view that composes rendering and app-level debug controls.
///
/// The view receives runtime capabilities from the App composition root. It
/// does not own simulation truth: the Metal scene consumes immutable
/// presentation snapshots, while controls change the real-time assembly's
/// independently owned advancement policy.
struct ContentView: View {
    let realtimeAssembly: RealtimeAssembly
    let debugOptions: AppDebugOptions
    let renderAssetCatalog: RenderAssetCatalog

    private var simulation: SimulationRuntime {
        realtimeAssembly.simulationRuntime
    }

    var body: some View {
        ZStack {
            MetalSceneView(
                renderAssetCatalog: renderAssetCatalog,
                presentationSource: simulation,
                viewpointSource: realtimeAssembly.screenViewpointController,
                inputSink: realtimeAssembly,
                outputMode: debugOptions.renderOutputMode
            )
                .ignoresSafeArea()

            Button {
                toggleSimulation()
            } label: {
                Label(
                    realtimeAssembly.isAdvancementActive
                        ? "Simulation Running"
                        : "Simulation Paused",
                    systemImage: realtimeAssembly.isAdvancementActive
                        ? "pause.fill"
                        : "play.fill"
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
        if realtimeAssembly.isAdvancementActive {
            realtimeAssembly.pauseAdvancement()
        } else {
            realtimeAssembly.resumeAdvancement()
        }
    }
}
