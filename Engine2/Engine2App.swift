import SwiftUI

/// The application composition root for Engine2's independently owned runtimes.
///
/// `Engine2App` selects a Runtime Configuration, retains its concrete assembly,
/// and supplies narrow Runtime capabilities to the UI and Render boundary. It
/// also applies app-scene lifecycle policy so no Runtime needs to discover or
/// control a peer through global state.
@main
struct Engine2App: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var debugOptions = AppDebugOptions()
    @State private var snapshotCaptureViewModel: SnapshotCaptureViewModel
    @State private var lifecycleRequestID: UInt64 = 0
    private let gameContent: BasicGameContent
    private let realtimeAssembly: RealtimeAssembly

    private let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

    init() {
        let gameContent = BasicGameContent()
        let realtimeAssembly = RealtimeConfiguration().makeAssembly(
            gameContent: gameContent
        )
        let snapshotCaptureViewModel: SnapshotCaptureViewModel

        do {
            let offscreenRenderRuntime = try MetalOffscreenRenderRuntime(
                catalog: gameContent.renderAssetCatalog
            )
            let captureConnection = RealtimeSnapshotCaptureConnection(
                presentationSource: realtimeAssembly.simulationRuntime,
                viewpointSource: realtimeAssembly.screenViewpointController,
                renderTarget: offscreenRenderRuntime
            )
            snapshotCaptureViewModel = SnapshotCaptureViewModel(
                captureTarget: captureConnection
            )
        } catch {
            snapshotCaptureViewModel = SnapshotCaptureViewModel(
                unavailableReason:
                    "The offline Metal renderer could not start. \(error)"
            )
        }

        self.gameContent = gameContent
        self.realtimeAssembly = realtimeAssembly
        _snapshotCaptureViewModel = State(
            initialValue: snapshotCaptureViewModel
        )
    }

    var body: some Scene {
        Window("Engine2", id: "main") {
            ContentView(
                presentationSource: realtimeAssembly.simulationRuntime,
                viewpointSource: realtimeAssembly.screenViewpointController,
                inputSink: realtimeAssembly,
                isSimulationRunning: {
                    realtimeAssembly.isAdvancementActive
                },
                inputHistory: {
                    realtimeAssembly.simulationRuntime.world.input.history
                },
                toggleSimulation: {
                    if realtimeAssembly.isAdvancementActive {
                        realtimeAssembly.pauseAdvancement()
                    } else {
                        realtimeAssembly.resumeAdvancement()
                    }
                },
                debugOptions: debugOptions,
                renderAssetCatalog: gameContent.renderAssetCatalog,
                snapshotCaptureViewModel: snapshotCaptureViewModel
            )
        }
        .commands {
            CommandMenu("Debug") {
                Toggle("Show Input History", isOn: $debugOptions.showsInputHistory)

                Picker("Render Output", selection: $debugOptions.renderOutputMode) {
                    Text("Surface").tag(RenderOutputMode.surface)
                    Text("View-Space Normals").tag(RenderOutputMode.viewSpaceNormals)
                }
            }
        }
        .onChange(of: scenePhase, initial: true) { _, newPhase in
            precondition(
                lifecycleRequestID < .max,
                "App lifecycle request identity exhausted."
            )
            lifecycleRequestID += 1
            let requestID = lifecycleRequestID

            Task { @MainActor in
                guard lifecycleRequestID == requestID else {
                    return
                }

                if isRunningTests {
                    await realtimeAssembly.stop()
                    return
                }

                // On macOS, an active scene need not be frontmost and should
                // continue normal work. An inactive scene receives no events
                // and should pause; a background scene is no longer visible.
                // Keep that policy at the App boundary rather than tying
                // Runtime lifecycle to an individual view's appearance.
                switch newPhase {
                case .active:
                    realtimeAssembly.start()
                case .inactive, .background:
                    await realtimeAssembly.stop()
                @unknown default:
                    await realtimeAssembly.stop()
                }
            }
        }
    }
}
