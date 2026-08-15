import SwiftUI

/// Hosts the seed-driven star-system visualization in one macOS window.
@main
struct StarSystemExplorerApp: App {
    var body: some Scene {
        Window("Star System Explorer", id: "main") {
            StarSystemExplorerView()
        }
        .defaultSize(width: 1_280, height: 900)
    }
}
