/// Exclusive reuse state for one single-flight offscreen Metal Runtime.
///
/// A Runtime is ready for a request, actively owns its sole mutable frame slot,
/// or retains a terminal GPU failure that makes later reuse unsafe. The failure
/// state cannot coexist with an apparently available or in-flight Runtime.
enum MetalOffscreenRenderState: Equatable {
    case ready
    case rendering
    case failed(OffscreenRenderFailure)
}
