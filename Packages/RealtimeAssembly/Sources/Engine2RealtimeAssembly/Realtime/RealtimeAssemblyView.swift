import Engine2
import Engine2AssemblySupport
import SwiftUI

/// Presents one real-time assembly and translates scene state into its lifecycle.
///
/// The assembly body owns root visibility. This view adds scene-phase transitions
/// while keeping topology-specific presentation state local.
struct RealtimeAssemblyView: View {
    @Environment(\.scenePhase) private var scenePhase

    let assembly: RealtimeAssembly
    let snapshotCaptureViewModel: SnapshotCaptureViewModel

    @State private var debugOptions = AppDebugOptions()

    var body: some View {
        ContentView(
            model: assembly,
            debugOptions: debugOptions,
            snapshotCaptureViewModel: snapshotCaptureViewModel
        )
        .toolbar {
            RealtimeAssemblyToolbar(debugOptions: $debugOptions)
        }
        .onChange(of: scenePhase, initial: true) { _, newPhase in
            apply(newPhase)
        }
    }

    private func apply(_ newPhase: ScenePhase) {
        // On macOS, an active scene need not be frontmost and should continue
        // normal work. An inactive scene receives no events and should pause;
        // a background scene is no longer visible.
        switch newPhase {
        case .active:
            assembly.setSceneActive(true)
        case .inactive, .background:
            assembly.setSceneActive(false)
        @unknown default:
            assembly.setSceneActive(false)
        }
    }
}
