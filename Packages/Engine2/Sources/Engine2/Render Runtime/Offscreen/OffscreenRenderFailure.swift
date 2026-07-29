/// Unexpected backend failure after an offscreen request was accepted.
public nonisolated struct OffscreenRenderFailure: Error, Equatable, Sendable {
    public let stage: OffscreenRenderFailureStage

    /// Open-ended diagnostic supplied by Metal, a driver, or another backend.
    ///
    /// This is intentionally a `String`: unlike the closed lifecycle stage,
    /// external diagnostic vocabularies are neither finite nor engine-owned.
    public let backendDescription: String

    public init(
        stage: OffscreenRenderFailureStage,
        backendDescription: String
    ) {
        self.stage = stage
        self.backendDescription = backendDescription
    }
}
