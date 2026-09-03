import SwiftUI

/// Selects and retains the Runtime Assembly presented by the main window.
///
/// The App selects Game Content and one assembly type. The assembly constructs
/// its complete topology, owns lifecycle policy, and supplies its root UI.
@main
struct Engine2App: App {
    private let assembly: some RuntimeAssembly = RealtimeAssembly(using: MiningGameContent())

    var body: some Scene {
        Window("Engine2", id: "main") {
            assembly
        }
    }
}
