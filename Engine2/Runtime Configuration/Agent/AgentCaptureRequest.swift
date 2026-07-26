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

    /// Projects an accepted advance source into the lower-level workflow.
    func makeOfflineCaptureRequest(expectedCursor: SimulationCursor, stepCount: SimulationStepCount) -> OfflineCaptureRequest {
        let advanceRequest = SimulationAdvanceRequest(
            expectedCursor: expectedCursor,
            stepCount: stepCount,
            inputAssignment: .none
        )
        return OfflineCaptureRequest(
            advanceRequest: advanceRequest,
            renderRequestID: renderRequestID,
            viewpoint: viewpoint,
            renderSettings: renderSettings,
            encoding: encoding
        )
    }

    /// Projects an accepted current source into the lower-level workflow.
    func makeOfflineCurrentCaptureRequest(expectedCursor: SimulationCursor) -> OfflineCurrentCaptureRequest {
        OfflineCurrentCaptureRequest(
            expectedCursor: expectedCursor,
            renderRequestID: renderRequestID,
            viewpoint: viewpoint,
            renderSettings: renderSettings,
            encoding: encoding
        )
    }
}
