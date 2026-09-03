import SwiftUI

/// Controls topology-local diagnostics and Render presentation for the real-time assembly.
struct RealtimeAssemblyToolbar: ToolbarContent {
    @Binding var debugOptions: AppDebugOptions

    var body: some ToolbarContent {
        ToolbarItem {
            Menu("Debug", systemImage: "ladybug") {
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
}
