import SwiftUI
import UniformTypeIdentifiers

/// Owns the bounded refresh task for the expanded dashboard.
struct DiagnosticsDashboardHost: View {
    @State private var model: DiagnosticsDashboardModel
    @State private var exportDocument: DiagnosticsSnapshotExportDocument?
    @State private var isExporting = false
    @State private var exportError: String?
    private let fixedStepNanoseconds: UInt64

    init(
        controller: any PDiagnosticsController,
        fixedStepNanoseconds: UInt64
    ) {
        _model = State(initialValue: DiagnosticsDashboardModel(controller: controller))
        self.fixedStepNanoseconds = fixedStepNanoseconds
    }

    var body: some View {
        VStack(spacing: 0) {
            controls
            Divider()
            DiagnosticsDashboard(presentation: model.presentation)
        }
            .task {
                while !Task.isCancelled {
                    model.refresh()
                    try? await Task.sleep(for: .milliseconds(200))
                }
            }
            .fileExporter(
                isPresented: $isExporting,
                document: exportDocument,
                contentType: .json,
                defaultFilename: "Engine2-Diagnostics.ndjson"
            ) { result in
                exportDocument = nil
                if case let .failure(error) = result {
                    exportError = error.localizedDescription
                }
            }
            .alert(
                "Diagnostics Export Failed",
                isPresented: Binding(
                    get: { exportError != nil },
                    set: { if !$0 { exportError = nil } }
                )
            ) {
                Button("OK", role: .cancel) { exportError = nil }
            } message: {
                Text(exportError ?? "The export could not be completed.")
            }
    }

    private var controls: some View {
        HStack {
            Button(model.isPaused ? "Resume View" : "Pause View") {
                model.togglePaused()
            }
            Slider(
                value: Binding(
                    get: { model.scrubFraction },
                    set: model.setScrubFraction
                ),
                in: 0...1
            )
            .frame(maxWidth: 220)
            .accessibilityIdentifier("diagnostics.dashboard.scrubber")
            Button("Start Capture") { model.startCaptureSession() }
            Button("Stop Capture") { model.stopCaptureSession() }
            Button("Reset") { model.reset() }
            Button("Export…") {
                exportDocument = try? DiagnosticsSnapshotExportDocument(
                    snapshot: model.exportSnapshot(),
                    fixedStepNanoseconds: fixedStepNanoseconds
                )
                isExporting = true
            }
        }
        .buttonStyle(.bordered)
        .padding(12)
        .accessibilityIdentifier("diagnostics.dashboard.controls")
    }
}
