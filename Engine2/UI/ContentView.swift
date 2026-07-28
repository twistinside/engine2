import SwiftUI
import UniformTypeIdentifiers

/// Real-time topology content that composes rendering and debug controls.
///
/// ``RealtimeAssemblyView`` supplies one narrow assembly model. This view does
/// not acquire exact advancement or lifecycle authority: the Metal scene
/// consumes immutable presentation snapshots, while controls toggle assembly
/// policy or request a detached artifact through assembly-owned connections.
struct ContentView: View {
    let model: any PRealtimeAssemblyViewModel
    let debugOptions: AppDebugOptions
    let snapshotCaptureViewModel: SnapshotCaptureViewModel

    @State private var captureTask: Task<Void, Never>?

    var body: some View {
        let captureModel = snapshotCaptureViewModel
        let exporter = captureModel.presentedModal?.exporter
        let failure = captureModel.presentedModal?.failure

        ZStack {
            MetalSceneView(
                renderAssetCatalog: model.renderAssetCatalog,
                presentationSource: model.presentationSource,
                inputSink: model.inputSink,
                outputMode: debugOptions.renderOutputMode
            )
                .ignoresSafeArea()

            SimulationControls(
                isSimulationRunning: model.isAdvancementActive,
                isCapturingSnapshot: captureModel.isCapturing,
                toggleSimulation: model.toggleAdvancement,
                captureSnapshot: captureSnapshot
            )
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)

            if debugOptions.showsInputHistory {
                InputHistoryPane {
                    model.inputHistoryEntries
                }
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
            isPresented: exporterPresentationBinding,
            document: exporter?.document,
            contentTypes: [.jpeg],
            defaultFilename: exporter?.defaultFilename ?? "Engine2 Snapshot"
        ) { result in
            captureModel.exportCompleted(result)
        } onCancellation: {
            captureModel.exportCancelled()
        }
        .fileDialogConfirmationLabel("Save JPEG")
        .fileDialogMessage("Choose where to save the offscreen snapshot.")
        .fileExporterFilenameLabel("Snapshot name")
        .alert(
            failure?.allowsExportRetry == true
                ? "Snapshot Save Failed"
                : "Snapshot Capture Failed",
            isPresented: failurePresentationBinding
        ) {
            if failure?.allowsExportRetry == true {
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
            Text(failure?.message ?? "")
        }
    }

    /// Adapts enum state to SwiftUI without clearing the export payload before
    /// the framework invokes its completion or cancellation callback.
    private var exporterPresentationBinding: Binding<Bool> {
        Binding(
            get: { snapshotCaptureViewModel.presentedModal?.exporter != nil },
            set: { _ in }
        )
    }

    /// Lets alert actions own the authoritative transition after SwiftUI writes
    /// its presentation binding during dismissal.
    private var failurePresentationBinding: Binding<Bool> {
        Binding(
            get: { snapshotCaptureViewModel.presentedModal?.failure != nil },
            set: { _ in }
        )
    }

    private func captureSnapshot() {
        captureTask = Task {
            await snapshotCaptureViewModel.capture(
                outputMode: debugOptions.renderOutputMode
            )
        }
    }
}
