import SwiftUI
import UniformTypeIdentifiers

/// Root application view that composes rendering and app-level debug controls.
///
/// The view receives runtime capabilities from the App composition root. It
/// does not own simulation truth: the Metal scene consumes immutable
/// presentation snapshots, while controls change advancement policy or request
/// a detached offscreen artifact through an App-owned connection.
struct ContentView: View {
    let presentationSource: any PSimulationPresentationSource
    let viewpointSource: any PRenderViewpointSource
    let inputSink: any PInputEventSink
    let isSimulationRunning: @MainActor () -> Bool
    let inputHistory: @MainActor () -> [InputHistoryEntry]
    let toggleSimulation: () -> Void
    let debugOptions: AppDebugOptions
    let renderAssetCatalog: RenderAssetCatalog
    let snapshotCaptureViewModel: SnapshotCaptureViewModel

    @State private var captureTask: Task<Void, Never>?

    var body: some View {
        @Bindable var captureModel = snapshotCaptureViewModel

        ZStack {
            MetalSceneView(
                renderAssetCatalog: renderAssetCatalog,
                presentationSource: presentationSource,
                viewpointSource: viewpointSource,
                inputSink: inputSink,
                outputMode: debugOptions.renderOutputMode
            )
                .ignoresSafeArea()

            SimulationControls(
                isSimulationRunning: isSimulationRunning(),
                isCapturingSnapshot: captureModel.isCapturing,
                toggleSimulation: toggleSimulation,
                captureSnapshot: captureSnapshot
            )
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)

            if debugOptions.showsInputHistory {
                InputHistoryPane(entries: inputHistory)
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .onAppear {
            captureModel.activatePresentation()
        }
        .onDisappear {
            captureTask?.cancel()
            captureTask = nil
            captureModel.deactivatePresentation()
        }
        .fileExporter(
            isPresented: $captureModel.isExporterPresented,
            document: captureModel.exportDocument,
            contentTypes: [.jpeg],
            defaultFilename: captureModel.defaultFilename
        ) { result in
            captureModel.exportCompleted(result)
        } onCancellation: {
            captureModel.exportCancelled()
        }
        .fileDialogConfirmationLabel("Save JPEG")
        .fileDialogMessage("Choose where to save the offscreen snapshot.")
        .fileExporterFilenameLabel("Snapshot name")
        .alert(
            captureModel.failureAllowsExportRetry
                ? "Snapshot Save Failed"
                : "Snapshot Capture Failed",
            isPresented: $captureModel.isFailurePresented
        ) {
            if captureModel.failureAllowsExportRetry {
                Button("Try Again", action: captureModel.retryExport)
                Button(
                    "Discard",
                    role: .destructive,
                    action: captureModel.discardExport
                )
            } else {
                Button("OK", role: .cancel, action: captureModel.dismissFailure)
            }
        } message: {
            Text(captureModel.failureMessage)
        }
    }

    private func captureSnapshot() {
        captureTask = Task {
            await snapshotCaptureViewModel.capture(
                outputMode: debugOptions.renderOutputMode
            )
        }
    }
}
