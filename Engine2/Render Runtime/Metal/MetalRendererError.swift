/// Failure encountered while resolving renderer model resources.
///
/// Model resolution fails resource-store construction before frame encoding.
nonisolated enum MetalRendererError: Error, Equatable {
    case missingModel(String)
}
