/// Packaged model formats supported by the current Render Runtime.
///
/// The raw string is deliberate because source URLs use an open-ended filename
/// extension while the current decoder supports this closed format set.
nonisolated public enum ModelAssetFormat: String, Equatable, Hashable, Sendable {
    case usdz
}
