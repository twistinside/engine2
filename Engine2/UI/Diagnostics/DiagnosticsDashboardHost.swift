import SwiftUI

/// Owns the bounded refresh task for the expanded dashboard.
struct DiagnosticsDashboardHost: View {
    @State private var model: DiagnosticsDashboardModel

    init(source: any PDiagnosticsSnapshotSource) {
        _model = State(initialValue: DiagnosticsDashboardModel(source: source))
    }

    var body: some View {
        DiagnosticsDashboard(presentation: model.presentation)
            .task {
                while !Task.isCancelled {
                    model.refresh()
                    try? await Task.sleep(for: .milliseconds(200))
                }
            }
    }
}
