import SwiftUI

/// Real-time topology content that composes rendering and debug controls.
///
/// ``RealtimeAssemblyView`` supplies one narrow assembly model. This view does
/// not acquire exact advancement or lifecycle authority: the Metal scene
/// consumes immutable presentation snapshots, while controls toggle assembly
/// policy or stage one focused maneuver through assembly-owned connections.
struct ContentView: View {
    let model: any RealtimeAssemblyViewModel
    let debugOptions: AppDebugOptions

    var body: some View {
        HStack(spacing: 0) {
            ZStack {
                MetalSceneView(
                    renderAssetCatalog: model.renderAssetCatalog,
                    presentationSource: model.presentationSource,
                    inputSink: model.inputSink,
                    outputMode: debugOptions.renderOutputMode
                )
                .ignoresSafeArea()

                SimulationControls(
                    isSimulationRunning: model.isAdvancementActive,
                    toggleSimulation: model.toggleAdvancement,
                    restartSimulation: model.restartSession
                )
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            }

            Divider()

            SelectedEntityInspector(
                source: model.selectedEntitySource,
                isAdvancementActive: model.isAdvancementActive,
                requestOrbitCircularization: model.requestOrbitCircularization
            )
                .frame(width: 320)
        }
    }
}
