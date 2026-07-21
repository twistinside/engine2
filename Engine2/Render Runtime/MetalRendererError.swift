/// Failures encountered while resolving or encoding Metal renderer resources.
///
/// A missing drawable is a normal transient MetalKit condition and never
/// appears here. Model resolution fails renderer construction, while encoder
/// failures mean a command buffer was available but a required frame phase
/// could not be created; the latter are recorded as terminal render errors.
nonisolated enum MetalRendererError: Error, Equatable {
    case missingModel(String)
    case missingSceneEncoder
    case missingPresentationEncoder
}
