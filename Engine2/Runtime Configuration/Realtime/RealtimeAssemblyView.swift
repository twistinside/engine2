import SwiftUI

/// Presents one real-time assembly and translates scene state into its lifecycle.
///
/// The view keeps topology-specific presentation state local, projects its
/// concrete assembly into a narrow child-view model, and preserves the
/// assembly's generation-guarded stop-and-drain ordering across overlapping
/// scene transitions and removal.
struct RealtimeAssemblyView: View {
    @Environment(\.scenePhase) private var scenePhase

    let assembly: RealtimeAssembly
    let snapshotCaptureViewModel: SnapshotCaptureViewModel

    @State private var debugOptions = AppDebugOptions()
    @State private var lifecycleRequestID: UInt64 = 0

    private var suppressesAutomaticLifecycle: Bool {
        let environment = ProcessInfo.processInfo.environment
        return environment["XCTestConfigurationFilePath"] != nil ||
            environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    var body: some View {
        ContentView(
            model: assembly,
            debugOptions: debugOptions,
            snapshotCaptureViewModel: snapshotCaptureViewModel
        )
        .toolbar {
            ToolbarItem {
                Menu("Debug", systemImage: "ladybug") {
                    Toggle(
                        "Show Input History",
                        isOn: $debugOptions.showsInputHistory
                    )

                    Picker(
                        "Render Output",
                        selection: $debugOptions.renderOutputMode
                    ) {
                        Text("Surface").tag(RenderOutputMode.surface)
                        Text("View-Space Normals").tag(
                            RenderOutputMode.viewSpaceNormals
                        )
                    }
                }
            }
        }
        .onChange(of: scenePhase, initial: true) { _, newPhase in
            apply(newPhase)
        }
        .onDisappear {
            stopForDisappearance()
        }
    }

    private func apply(_ newPhase: ScenePhase) {
        precondition(
            lifecycleRequestID < .max,
            "Real-time view lifecycle request identity exhausted."
        )
        lifecycleRequestID += 1
        let requestID = lifecycleRequestID

        Task { @MainActor in
            guard lifecycleRequestID == requestID else {
                return
            }

            if suppressesAutomaticLifecycle {
                await assembly.stop()
                return
            }

            // On macOS, an active scene need not be frontmost and should
            // continue normal work. An inactive scene receives no events and
            // should pause; a background scene is no longer visible.
            switch newPhase {
            case .active:
                assembly.start()
            case .inactive, .background:
                await assembly.stop()
            @unknown default:
                await assembly.stop()
            }
        }
    }

    /// Invalidates a queued scene transition before draining a removed root view.
    private func stopForDisappearance() {
        precondition(
            lifecycleRequestID < .max,
            "Real-time view lifecycle request identity exhausted."
        )
        lifecycleRequestID += 1
        let requestID = lifecycleRequestID

        Task { @MainActor in
            guard lifecycleRequestID == requestID else {
                return
            }
            await assembly.stop()
        }
    }
}

#Preview {
    RealtimeAssembly()
        .frame(width: 960, height: 640)
}
