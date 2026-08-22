/// Packaged model formats supported by the current Render Runtime.
///
/// The raw string preserves the source file's extension for validation and
/// diagnostics without exposing a decoder-specific type to Game Content.
nonisolated enum ModelAssetFormat: String, Equatable, Hashable, Sendable {
    case usdz
}
