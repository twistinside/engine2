/// One idempotent, bounded agent request for exact advancement and capture.
///
/// The caller must supply the expected authoritative cursor and preserve the
/// entire value across retries. A changed render identity, viewpoint, settings,
/// or step count at the same request ID is a conflict, not a new command.
/// Physical and semantic input remain absent until typed source/route ownership
/// exists; this first agent slice always advances with `.none` input assignment.
nonisolated struct AgentCaptureRequest: Equatable, Sendable {
    let id: AgentSessionRequestID
    let expectedCursor: SimulationCursor
    let stepCount: SimulationStepCount
    let renderRequestID: OffscreenRenderRequestID
    let viewpoint: RenderViewpoint
    let renderSettings: OffscreenRenderSettings
    let jpegSettings: JPEGEncodingSettings

    /// Creates one stable request value suitable for exact retry comparison.
    init(
        id: AgentSessionRequestID,
        expectedCursor: SimulationCursor,
        stepCount: SimulationStepCount,
        renderRequestID: OffscreenRenderRequestID = OffscreenRenderRequestID(),
        viewpoint: RenderViewpoint,
        renderSettings: OffscreenRenderSettings,
        jpegSettings: JPEGEncodingSettings = JPEGEncodingSettings()
    ) {
        self.id = id
        self.expectedCursor = expectedCursor
        self.stepCount = stepCount
        self.renderRequestID = renderRequestID
        self.viewpoint = viewpoint
        self.renderSettings = renderSettings
        self.jpegSettings = jpegSettings
    }

    /// Projects agent policy into the sole lower-level workflow capability.
    func makeOfflineCaptureRequest() -> OfflineCaptureRequest {
        OfflineCaptureRequest(
            advanceRequest: SimulationAdvanceRequest(
                expectedCursor: expectedCursor,
                stepCount: stepCount,
                inputAssignment: .none
            ),
            renderRequestID: renderRequestID,
            viewpoint: viewpoint,
            renderSettings: renderSettings,
            jpegSettings: jpegSettings
        )
    }
}
