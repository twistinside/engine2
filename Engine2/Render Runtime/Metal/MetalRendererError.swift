/// Failure encountered while resolving fixed renderer resources.
///
/// Resolution fails renderer or resource-store construction before frame encoding.
nonisolated enum MetalRendererError: Error, Equatable {
    case couldNotCreateSRGBColorSpace
    case missingModel(ModelAssetReference)
    case missingTexture(TextureAssetReference)
}
