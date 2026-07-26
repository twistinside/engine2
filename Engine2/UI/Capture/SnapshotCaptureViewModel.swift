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
            presentFailure(reason)
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
        handle(outcome)
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

    private func handle(_ outcome: RealtimeSnapshotCaptureOutcome) {
        switch outcome {
        case let .completed(sourceSnapshot, artifact):
            presentedModal = .exporter(
                document: JPEGArtifactDocument(artifact: artifact),
                defaultFilename: "Engine2-tick-\(sourceSnapshot.cursor.tick.rawValue)"
            )

        case .connectionBusy:
            presentFailure("Another snapshot capture is already in progress.")

        case .cancelledBeforeRender:
            presentFailure("Snapshot capture was cancelled before rendering.")

        case let .renderRejected(_, rejection):
            presentFailure(message(for: rejection))

        case let .renderFailed(_, failure):
            presentFailure(
                "The offline renderer failed during \(failure.stage). "
                    + failure.backendDescription
            )

        case .renderCancellationRequestIDMismatch:
            presentFailure(
                "The offline renderer returned cancellation for the wrong request."
            )

        case .renderCancelledAfterSubmission:
            presentFailure(
                "Snapshot capture was cancelled after GPU submission completed."
            )

        case .renderResultMismatch:
            presentFailure(
                "The offline renderer returned an image that did not match "
                    + "the selected snapshot or output settings."
            )

        case .artifactResultMismatch:
            presentFailure(
                "The image encoder returned an artifact that did not match "
                    + "the selected snapshot or output settings."
            )

        case .cancelledAfterRender:
            presentFailure(
                "Snapshot capture was cancelled before JPEG encoding began."
            )

        case let .artifactEncodingFailed(_, _, failure):
            presentFailure(message(for: failure))
        }
    }

    private func message(for rejection: OffscreenRenderRejection) -> String {
        switch rejection {
        case .runtimeBusy:
            "The offline renderer is busy with another request."

        case .cancelledBeforeSubmission:
            "Snapshot capture was cancelled before GPU submission."

        case .invalidViewpoint:
            "The selected Simulation camera cannot be rendered offscreen."

        case .invalidPresentation:
            "The selected Simulation snapshot contains invalid presentation data."

        case let .exceedsLimits(requested, limits):
            "The requested \(requested.width)×\(requested.height) image exceeds "
                + "the offline limit of \(limits.maxDimension) pixels per side "
                + "and \(limits.maxPixelCount) total pixels."

        case let .instanceLimitExceeded(requested, maximum):
            "The selected snapshot contains \(requested) render instances; "
                + "the offline renderer supports \(maximum)."
        }
    }

    private func message(for failure: ImageArtifactEncoderError) -> String {
        switch failure {
        case .couldNotCreateSRGBColorSpace:
            "The system could not create the sRGB color space for JPEG export."

        case .couldNotCreateDataProvider:
            "The rendered pixels could not be opened for JPEG export."

        case .couldNotCreateImage:
            "The rendered pixel layout could not be converted into an image."

        case .couldNotCreateDestination:
            "The system could not create an in-memory JPEG destination."

        case .destinationFinalizationFailed:
            "The system could not finish encoding the JPEG."
        }
    }

    private func presentFailure(_ message: String) {
        presentedModal = .captureFailure(message: message)
    }
}
