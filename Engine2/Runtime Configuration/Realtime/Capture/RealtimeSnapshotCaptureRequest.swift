/// Immutable output policy for one live real-time presentation capture.
///
/// The App-owned connection selects the Simulation snapshot when this request
/// is admitted and uses that snapshot's camera for the offscreen request. The
/// request itself carries no advance command and cannot mutate Simulation.
nonisolated struct RealtimeSnapshotCaptureRequest: Equatable, Sendable {
    let renderRequestID: OffscreenRenderRequestID
    let renderSettings: OffscreenRenderSettings
    let encoding: ImageArtifactEncoding

    /// Creates one exact current-presentation capture request.
    init(
        renderRequestID: OffscreenRenderRequestID = OffscreenRenderRequestID(),
        renderSettings: OffscreenRenderSettings,
        encoding: ImageArtifactEncoding = .observationJPEG
    ) {
        self.renderRequestID = renderRequestID
        self.renderSettings = renderSettings
        self.encoding = encoding
    }
}
