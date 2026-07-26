import Foundation
import Observation

/// Observable presentation state for user-initiated snapshot capture and export.
///
/// The model requests one artifact through a narrow App-owned connection, then
/// exposes a detached file document to SwiftUI. It never samples Simulation,
/// resolves a viewpoint, calls Metal directly, or writes a destination itself.
@Observable
final class SnapshotCaptureViewModel {
    private(set) var isCapturing = false
    private(set) var presentedModal: SnapshotCapturePresentation?

    @ObservationIgnored
    private let availability: SnapshotCaptureAvailability

    @ObservationIgnored
    private let renderSize: RenderPixelSize

    @ObservationIgnored
    private var isPresentationActive = false

    @ObservationIgnored
    private var presentationGeneration: UInt64 = 0

    /// Creates an available UI model around the App-owned capture capability.
    init(captureTarget: any PRealtimeSnapshotCaptureTarget, renderSize: RenderPixelSize) {
        self.availability = .available(captureTarget)
        self.renderSize = renderSize
    }

    /// Creates a model that reports a retained Render initialization failure.
    ///
    /// `reason` is intentionally open-ended because Metal and driver diagnostic
    /// vocabularies are external to Engine2's closed capture state.
    init(unavailableReason reason: String, renderSize: RenderPixelSize) {
        self.availability = .unavailable(reason: reason)
        self.renderSize = renderSize
    }

    /// Marks the window presentation lane as available for capture results.
    func activatePresentation() {
        isPresentationActive = true
    }

    /// Invalidates work associated with a disappearing window.
    ///
    /// A completed GPU or JPEG operation may still return after cancellation.
    /// Advancing the generation prevents that stale completion from opening a
    /// save panel in a later presentation of the window.
    func deactivatePresentation() {
        precondition(presentationGeneration < .max, "Snapshot presentation generation exhausted.")
        presentationGeneration += 1
        isPresentationActive = false
        presentedModal = nil
    }

    /// Renders the current presentation and opens export state on completion.
    func capture(outputMode: RenderOutputMode) async {
        guard isPresentationActive, !isCapturing else {
            return
        }

        let captureTarget: any PRealtimeSnapshotCaptureTarget
        switch availability {
        case let .available(target):
            captureTarget = target

        case let .unavailable(reason):
            presentedModal = .captureFailure(message: reason)
            return
        }

        let selectedPresentationGeneration = presentationGeneration
        presentedModal = nil
        isCapturing = true
        defer {
            isCapturing = false
        }

        let request = RealtimeSnapshotCaptureRequest(
            renderRequestID: OffscreenRenderRequestID(),
            renderSettings: OffscreenRenderSettings(
                size: renderSize,
                outputMode: outputMode,
                exposure: .validation
            ),
            encoding: .jpeg(quality: .maximum)
        )
        let outcome = await captureTarget.capture(request)
        guard
            isPresentationActive,
            presentationGeneration == selectedPresentationGeneration
        else {
            return
        }
        presentedModal = SnapshotCapturePresentation(
            jpegCaptureOutcome: outcome
        )
    }

    /// Resolves SwiftUI's attempt to write the detached JPEG.
    ///
    /// A failed write retains the already-rendered document so retrying never
    /// resamples Simulation or repeats GPU and JPEG work.
    func exportCompleted(_ result: Result<URL, any Error>) {
        guard case let .exporter(document, defaultFilename) = presentedModal else {
            return
        }

        switch result {
        case .success:
            presentedModal = nil

        case let .failure(error):
            presentedModal = .exportFailure(
                message: "The rendered JPEG could not be saved. \(error.localizedDescription)",
                document: document,
                defaultFilename: defaultFilename
            )
        }
    }

    /// Reopens the save panel around the exact retained JPEG document.
    func retryExport() {
        guard case let .exportFailure(_, document, defaultFilename) = presentedModal else {
            discardExport()
            return
        }

        presentedModal = .exporter(document: document, defaultFilename: defaultFilename)
    }

    /// Discards a rendered JPEG after the user declines another save attempt.
    func discardExport() {
        presentedModal = nil
    }

    /// Discards the pending detached document when the save panel is cancelled.
    func exportCancelled() {
        discardExport()
    }

    /// Clears the current user-visible failure.
    func dismissFailure() {
        switch presentedModal {
        case .captureFailure, .exportFailure:
            presentedModal = nil

        case .exporter, nil:
            break
        }
    }

}
