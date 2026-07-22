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
    @State private var realtimeAssembly: RealtimeAssembly
    private let gameContent: BasicGameContent

    private let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

    init() {
        let gameContent = BasicGameContent()
        self.gameContent = gameContent
        _realtimeAssembly = State(
            initialValue: RealtimeConfiguration().makeAssembly(
                gameContent: gameContent
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView(
                inputRuntime: realtimeAssembly.inputRuntime,
                simulation: realtimeAssembly.simulationRuntime,
                debugOptions: debugOptions,
                renderAssetCatalog: gameContent.renderAssetCatalog
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
            if isRunningTests {
                realtimeAssembly.stop()
                return
            }

            // Keep the highest-level engine driver tied to app activity rather
            // than any individual view's lifecycle.
            switch newPhase {
            case .active:
                realtimeAssembly.start()
            case .inactive, .background:
                realtimeAssembly.stop()
            @unknown default:
                realtimeAssembly.stop()
            }
        }
    }
}
