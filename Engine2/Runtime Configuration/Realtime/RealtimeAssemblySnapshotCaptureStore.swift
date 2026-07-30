/// Retains the real-time assembly's optional snapshot presentation path.
///
/// SwiftUI may copy ``RealtimeAssembly`` values and evaluate their bodies
/// repeatedly. This reference owner constructs the expensive offscreen path only
/// on first UI demand and returns the same presentation model to every copy.
final class RealtimeAssemblySnapshotCaptureStore {
    private let presentationSource: any PSimulationPresentationSource
    private let renderAssetCatalog: RenderAssetCatalog
    private var storedViewModel: SnapshotCaptureViewModel?

    /// Snapshot presentation model shared by every view of this assembly.
    ///
    /// Capture construction failure leaves the required interactive graph usable
    /// and becomes unavailable presentation state.
    var viewModel: SnapshotCaptureViewModel {
        if let storedViewModel {
            return storedViewModel
        }

        let viewModel = makeViewModel()
        storedViewModel = viewModel
        return viewModel
    }

    init(
        presentationSource: any PSimulationPresentationSource,
        renderAssetCatalog: RenderAssetCatalog
    ) {
        self.presentationSource = presentationSource
        self.renderAssetCatalog = renderAssetCatalog
    }

    private func makeViewModel() -> SnapshotCaptureViewModel {
        do {
            let offscreenRenderRuntime = try MetalOffscreenRenderRuntime(
                catalog: renderAssetCatalog,
                limits: .conservative
            )
            let captureConnection = try RealtimeSnapshotCaptureConnection(
                presentationSource: presentationSource,
                renderTarget: offscreenRenderRuntime
            )
            return SnapshotCaptureViewModel(
                captureTarget: captureConnection,
                renderSize: .uhd4K
            )
        } catch {
            return SnapshotCaptureViewModel(
                unavailableReason: "Snapshot output could not start. \(error)",
                renderSize: .uhd4K
            )
        }
    }
}
