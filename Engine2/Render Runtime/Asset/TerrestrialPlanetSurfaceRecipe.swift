/// Immutable Game Content inputs for one procedural terrestrial surface.
///
/// Game Content selects the deterministic seed and virtual relief used by the
/// generated normal field. Render owns the map resolution, generation work,
/// pixel storage, and backend-resource lifetime.
nonisolated struct TerrestrialPlanetSurfaceRecipe: Equatable, Sendable {
    /// Largest virtual relief supported by the normal generator.
    static let maximumNormalRelief: Float = 0.1

    /// Blue Marble-inspired proof recipe selected by Basic Game Content.
    static let blueMarble = Self(
        seed: 0x4541_5254,
        normalRelief: 0.006
    )

    /// Deterministic identity for coast, biome, and weather variation.
    let seed: UInt64

    /// Maximum virtual land relief relative to the unit-radius surface.
    ///
    /// Values use the supported `0...0.1` range.
    /// The generator uses this value only to derive tangent-space normals. It
    /// does not displace the planet mesh or change its silhouette.
    let normalRelief: Float

    init(seed: UInt64, normalRelief: Float) {
        precondition(
            Self.acceptsNormalRelief(normalRelief),
            "Procedural planet normal relief must be finite and in 0...0.1."
        )

        self.seed = seed
        self.normalRelief = normalRelief
    }

    /// Whether relief stays within the generator's finite supported domain.
    static func acceptsNormalRelief(_ value: Float) -> Bool {
        value.isFinite && value >= 0 && value <= maximumNormalRelief
    }
}
