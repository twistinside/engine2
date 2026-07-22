/// Unexpected backend failure after an offscreen request was accepted.
nonisolated struct OffscreenRenderFailure: Equatable, Sendable {
    let stage: OffscreenRenderFailureStage

    /// Open-ended diagnostic supplied by Metal, a driver, or another backend.
    ///
    /// This is intentionally a `String`: unlike the closed lifecycle stage,
    /// external diagnostic vocabularies are neither finite nor engine-owned.
    let backendDescription: String

    /// Captures the stable failure stage and backend-authored diagnostic.
    init(stage: OffscreenRenderFailureStage, backendDescription: String) {
        self.stage = stage
        self.backendDescription = backendDescription
    }
}
