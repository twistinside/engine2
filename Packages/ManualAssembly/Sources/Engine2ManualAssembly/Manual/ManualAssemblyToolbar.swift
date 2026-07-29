import Engine2
import SwiftUI

/// Selects the Render output presented by the manual assembly.
struct ManualAssemblyToolbar: ToolbarContent {
    @Binding var outputMode: RenderOutputMode

    var body: some ToolbarContent {
        ToolbarItem {
            Picker("Render Output", selection: $outputMode) {
                Text("Surface").tag(RenderOutputMode.surface)
                Text("View-Space Normals").tag(
                    RenderOutputMode.viewSpaceNormals
                )
            }
        }
    }
}
