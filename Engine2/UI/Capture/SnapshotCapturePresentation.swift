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
