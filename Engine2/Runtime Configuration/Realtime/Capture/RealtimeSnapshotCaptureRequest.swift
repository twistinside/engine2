/// Immutable output policy for one live real-time presentation capture.
///
/// The App-owned connection selects the Simulation snapshot and screen
/// viewpoint together when this request is admitted. The request itself carries
/// no advance command and cannot mutate Simulation.
nonisolated struct RealtimeSnapshotCaptureRequest: Equatable, Sendable {
    let renderRequestID: OffscreenRenderRequestID
    let renderSettings: OffscreenRenderSettings
    let jpegSettings: JPEGEncodingSettings

    /// Creates one exact current-presentation capture request.
    init(
        renderRequestID: OffscreenRenderRequestID = OffscreenRenderRequestID(),
        renderSettings: OffscreenRenderSettings,
        jpegSettings: JPEGEncodingSettings = JPEGEncodingSettings()
    ) {
        self.renderRequestID = renderRequestID
        self.renderSettings = renderSettings
        self.jpegSettings = jpegSettings
    }
}
