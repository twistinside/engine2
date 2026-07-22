/// Expected refusal of an offscreen request before GPU submission begins.
nonisolated enum OffscreenRenderRejection: Equatable, Sendable {
    case runtimeBusy
    case cancelledBeforeSubmission
    case invalidViewpoint
    case invalidPresentation(RenderFrameProjectionError)
    case exceedsLimits(
        requested: RenderPixelSize,
        limits: OffscreenRenderLimits
    )
    case instanceLimitExceeded(requested: Int, maximum: Int)
}
