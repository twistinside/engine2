/// Mutually exclusive modal presentation owned by snapshot capture UI.
///
/// Each case carries exactly the payload valid for that presentation. In
/// particular, retryable export failure retains the exact detached document
/// and filename without permitting an unrelated capture failure to advertise
/// export retry.
enum SnapshotCapturePresentation: Equatable {
    case exporter(document: JPEGArtifactDocument, defaultFilename: String)
    case captureFailure(message: String)
    case exportFailure(message: String, document: JPEGArtifactDocument, defaultFilename: String)

    /// Projects one maximum-quality JPEG capture terminal into modal UI state.
    ///
    /// ``SnapshotCaptureViewModel`` always requests JPEG. A completed outcome
    /// from that capability must therefore contain a JPEG artifact; the document
    /// initializer enforces that production correlation invariant.
    init(jpegCaptureOutcome outcome: RealtimeSnapshotCaptureOutcome) {
        switch outcome {
        case let .completed(sourceSnapshot, artifact):
            self = .exporter(
                document: JPEGArtifactDocument(artifact: artifact),
                defaultFilename: "Engine2-tick-\(sourceSnapshot.cursor.tick.rawValue)"
            )

        case .connectionBusy:
            self = .captureFailure(
                message: "Another snapshot capture is already in progress."
            )

        case .cancelledBeforeRender:
            self = .captureFailure(
                message: "Snapshot capture was cancelled before rendering."
            )

        case let .renderRejected(_, rejection):
            let message = switch rejection {
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
            self = .captureFailure(message: message)

        case let .renderFailed(_, failure):
            self = .captureFailure(
                message: "The offline renderer failed during \(failure.stage). "
                    + failure.backendDescription
            )

        case .renderCancellationRequestIDMismatch:
            self = .captureFailure(
                message: "The offline renderer returned cancellation for the wrong request."
            )

        case .renderCancelledAfterSubmission:
            self = .captureFailure(
                message: "Snapshot capture was cancelled after GPU submission completed."
            )

        case .renderResultMismatch:
            self = .captureFailure(
                message: "The offline renderer returned an image that did not match "
                    + "the selected snapshot or output settings."
            )

        case .artifactResultMismatch:
            self = .captureFailure(
                message: "The image encoder returned an artifact that did not match "
                    + "the selected snapshot or output settings."
            )

        case .cancelledAfterRender:
            self = .captureFailure(
                message: "Snapshot capture was cancelled before JPEG encoding began."
            )

        case let .artifactEncodingFailed(_, _, failure):
            let message = switch failure {
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
            self = .captureFailure(message: message)
        }
    }

    /// Payload supplied only while SwiftUI should present the file exporter.
    var exporter: (document: JPEGArtifactDocument, defaultFilename: String)? {
        guard case let .exporter(document, defaultFilename) = self else {
            return nil
        }
        return (document, defaultFilename)
    }

    /// Message and action policy supplied only while SwiftUI shows an alert.
    var failure: (message: String, allowsExportRetry: Bool)? {
        switch self {
        case .exporter:
            nil

        case let .captureFailure(message):
            (message, false)

        case let .exportFailure(message, _, _):
            (message, true)
        }
    }
}
