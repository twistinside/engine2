import AppKit
import SwiftUI

/// Supplies an AppKit help tag for a SwiftUI surface that needs reliable macOS hover behavior.
struct HoverHelpSurface: NSViewRepresentable {
    let text: String

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.toolTip = text
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        nsView.toolTip = text
    }
}
