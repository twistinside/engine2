/// Backend-neutral mesh identity carried across the Game Content package boundary.
///
/// A Game Content package owns its exhaustive authored mesh enum and projects
/// each case into this open transport key. The selected catalog defines the
/// key's namespace; callers must not combine keys from independently authored
/// catalogs without introducing an explicit catalog identity.
nonisolated public struct MeshAssetKey: Codable, Hashable, RawRepresentable, Sendable {
    public let rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }
}
