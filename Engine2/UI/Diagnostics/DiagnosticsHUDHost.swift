import SwiftUI

/// Owns the bounded refresh task for the compact diagnostics presentation.
struct DiagnosticsHUDHost: View {
    @State private var model: DiagnosticsHUDModel

    init(source: any PDiagnosticsSnapshotSource) {
        _model = State(initialValue: DiagnosticsHUDModel(source: source))
    }

    var body: some View {
        DiagnosticsHUD(presentation: model.presentation)
            .task {
                while !Task.isCancelled {
                    model.refresh()
                    try? await Task.sleep(for: .milliseconds(200))
                }
            }
    }
}
