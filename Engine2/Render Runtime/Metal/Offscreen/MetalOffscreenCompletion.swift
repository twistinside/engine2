/// Queue-reported completion of one submitted Metal offscreen render.
///
/// The failure description is intentionally open-ended because Metal and its
/// driver own that diagnostic vocabulary. Stable engine policy is represented
/// separately by `OffscreenRenderFailureStage`.
nonisolated enum MetalOffscreenCompletion: Equatable, Sendable {
    case success
    case failure(String)
}
