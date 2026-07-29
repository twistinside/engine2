import Engine2
import Engine2AssemblySupport
import Engine2OfflineCaptureAssembly
/// One idempotent agent request for exact scene capture.
///
/// The caller must supply the expected authoritative cursor and preserve the
/// entire value across retries. A changed source operation, render identity,
/// viewpoint, render settings, or artifact encoding at the same request ID is
/// a conflict, not a command.
/// Physical and semantic input remain absent until typed source/route ownership
/// exists; advancing requests continue to use `.none` input assignment.
public nonisolated struct AgentCaptureRequest: Equatable, Sendable {
    public let id: AgentSessionRequestID
    public let source: AgentCaptureSource
    public let renderRequestID: OffscreenRenderRequestID
    public let viewpoint: RenderViewpoint
    public let renderSettings: OffscreenRenderSettings
    public let encoding: ImageArtifactEncoding

    public init(
        id: AgentSessionRequestID,
        source: AgentCaptureSource,
        renderRequestID: OffscreenRenderRequestID,
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
