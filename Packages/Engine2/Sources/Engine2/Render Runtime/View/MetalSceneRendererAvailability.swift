/// Construction state for one `MetalSceneView` renderer.
///
/// The view bridge either owns a fully constructed renderer or retains the
/// exact construction failure. It cannot expose a missing renderer without a
/// diagnostic or retain a stale failure beside a usable renderer.
enum MetalSceneRendererAvailability {
    case available(MetalRenderer)
    case unavailable(any Error)

    /// Renderer supplied to MetalKit only after successful construction.
    var renderer: MetalRenderer? {
        guard case let .available(renderer) = self else {
            return nil
        }
        return renderer
    }

    /// Construction error retained only when no renderer exists.
    var initializationError: (any Error)? {
        guard case let .unavailable(error) = self else {
            return nil
        }
        return error
    }
}
