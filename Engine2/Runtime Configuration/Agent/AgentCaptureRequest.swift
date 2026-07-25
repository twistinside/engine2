/// One idempotent agent request for exact scene capture.
///
/// The caller must supply the expected authoritative cursor and preserve the
/// entire value across retries. A changed source operation, render identity,
/// viewpoint, render settings, or artifact encoding at the same request ID is
/// a conflict, not a command.
/// Physical and semantic input remain absent until typed source/route ownership
/// exists; advancing requests continue to use `.none` input assignment.
nonisolated struct AgentCaptureRequest: Equatable, Sendable {
    let id: AgentSessionRequestID
    let source: AgentCaptureSource
    let renderRequestID: OffscreenRenderRequestID
    let viewpoint: RenderViewpoint
    let renderSettings: OffscreenRenderSettings
    let encoding: ImageArtifactEncoding

    /// Creates an advance-then-capture request compatible with the first API.
    init(
        id: AgentSessionRequestID,
        expectedCursor: SimulationCursor,
        stepCount: SimulationStepCount,
        renderRequestID: OffscreenRenderRequestID = OffscreenRenderRequestID(),
        viewpoint: RenderViewpoint,
        renderSettings: OffscreenRenderSettings,
        encoding: ImageArtifactEncoding
    ) {
        self.init(
            id: id,
            source: .advance(
                expectedCursor: expectedCursor,
                stepCount: stepCount
            ),
            renderRequestID: renderRequestID,
            viewpoint: viewpoint,
            renderSettings: renderSettings,
            encoding: encoding
        )
    }

    /// Creates one stable request from an explicitly selected scene source.
    init(
        id: AgentSessionRequestID,
        source: AgentCaptureSource,
        renderRequestID: OffscreenRenderRequestID = OffscreenRenderRequestID(),
        viewpoint: RenderViewpoint,
        renderSettings: OffscreenRenderSettings,
        encoding: ImageArtifactEncoding
    ) {
        self.id = id
        self.source = source
        self.renderRequestID = renderRequestID
        self.viewpoint = viewpoint
        self.renderSettings = renderSettings
        self.encoding = encoding
    }

    /// Creates a capture of an already completed cursor without advancing it.
    static func current(
        id: AgentSessionRequestID,
        expectedCursor: SimulationCursor,
        renderRequestID: OffscreenRenderRequestID = OffscreenRenderRequestID(),
        viewpoint: RenderViewpoint,
        renderSettings: OffscreenRenderSettings,
        encoding: ImageArtifactEncoding
    ) -> AgentCaptureRequest {
        AgentCaptureRequest(
            id: id,
            source: .current(expectedCursor: expectedCursor),
            renderRequestID: renderRequestID,
            viewpoint: viewpoint,
            renderSettings: renderSettings,
            encoding: encoding
        )
    }

    /// Projects an accepted advance source into the lower-level workflow.
    func makeOfflineCaptureRequest(
        expectedCursor: SimulationCursor,
        stepCount: SimulationStepCount
    ) -> OfflineCaptureRequest {
        OfflineCaptureRequest(
            advanceRequest: SimulationAdvanceRequest(
                expectedCursor: expectedCursor,
                stepCount: stepCount,
                inputAssignment: .none
            ),
            renderRequestID: renderRequestID,
            viewpoint: viewpoint,
            renderSettings: renderSettings,
            encoding: encoding
        )
    }

    /// Projects an accepted current source into the lower-level workflow.
    func makeOfflineCurrentCaptureRequest(
        expectedCursor: SimulationCursor
    ) -> OfflineCurrentCaptureRequest {
        OfflineCurrentCaptureRequest(
            expectedCursor: expectedCursor,
            renderRequestID: renderRequestID,
            viewpoint: viewpoint,
            renderSettings: renderSettings,
            encoding: encoding
        )
    }
}
