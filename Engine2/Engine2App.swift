import SwiftUI

/// The application composition root for Engine2's independently owned runtimes.
///
/// `Engine2App` constructs Game Content, wires the Input and Simulation
/// Runtimes explicitly, and supplies their narrow capabilities to the UI and
/// Render Runtime boundary. It also applies app-scene lifecycle policy so no
/// runtime needs to discover or control a peer through global state.
@main
struct Engine2App: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var debugOptions = AppDebugOptions()
    @State private var inputRuntime: InputRuntime
    @State private var simulation: SimulationRuntime
    private let gameContent: BasicGameContent

    private let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

    init() {
        let gameContent = BasicGameContent()
        let inputRuntime = InputRuntime()
        self.gameContent = gameContent
        _inputRuntime = State(initialValue: inputRuntime)
        _simulation = State(
            initialValue: SimulationRuntime(
                worldBuilder: gameContent.worldBuilder,
                inputSource: inputRuntime
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView(
                inputRuntime: inputRuntime,
                simulation: simulation,
                debugOptions: debugOptions,
                renderAssetCatalog: gameContent.renderAssetCatalog
            )
        }
        .commands {
            CommandMenu("Debug") {
                Toggle("Show Input History", isOn: $debugOptions.showsInputHistory)
            }
        }
        .onChange(of: scenePhase, initial: true) { _, newPhase in
            if isRunningTests {
                simulation.stop()
                inputRuntime.stop()
                return
            }

            // Keep the highest-level engine driver tied to app activity rather
            // than any individual view's lifecycle.
            switch newPhase {
            case .active:
                inputRuntime.start()
                simulation.start()
            case .inactive, .background:
                simulation.stop()
                inputRuntime.stop()
            @unknown default:
                simulation.stop()
                inputRuntime.stop()
            }
        }
    }
}
