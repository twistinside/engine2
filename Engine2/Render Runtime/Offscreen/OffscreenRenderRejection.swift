/// Expected refusal of an offscreen request before GPU submission begins.
nonisolated enum OffscreenRenderRejection: Equatable, Sendable {
    case runtimeBusy
    case cancelledBeforeSubmission
    case invalidViewpoint
    case invalidPresentation(RenderFrameProjectionError)
    case exceedsLimits(requested: RenderPixelSize, limits: OffscreenRenderLimits)
    case instanceLimitExceeded(requested: Int, maximum: Int)
}

extension OffscreenRenderRejection {
    /// Classifies one exact frame-projection failure at the offscreen boundary.
    init(_ projectionError: RenderFrameProjectionError) {
        switch projectionError {
        case .invalidSelectedCamera:
            self = .invalidViewpoint

        case .missingPosition,
             .unsupportedNormalTransform,
             .nonfiniteModelViewTransform,
             .nonfiniteModelViewProjectionTransform:
            self = .invalidPresentation(projectionError)
        }
    }
}
