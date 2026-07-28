import SwiftUI

/// Selects and retains the Runtime Assembly presented by the main window.
///
/// The selected assembly constructs its own complete topology, owns lifecycle
/// translation, and supplies its root UI. Changing the assembly type does not
/// require the App to understand that topology's runtimes or capabilities.
@main
struct Engine2App: App {
    private let assembly: some PRuntimeAssembly = RealtimeAssembly()

    var body: some Scene {
        Window("Engine2", id: "main") {
            assembly
        }
    }
}
