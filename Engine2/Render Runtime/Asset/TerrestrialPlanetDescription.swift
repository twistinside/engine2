/// Immutable authored inputs for one layered terrestrial-planet material.
///
/// Game Content supplies a deterministic surface recipe and normalized
/// local-space layer parameters. Render privately generates the sampled maps
/// and expands one material into surface, cloud, and atmosphere work while
/// Simulation continues to publish one entity.
nonisolated struct TerrestrialPlanetDescription: Equatable, Sendable {
    /// Recipe from which Render generates all immutable surface and weather maps.
    let surfaceRecipe: TerrestrialPlanetSurfaceRecipe

    /// Radius of the opaque surface in model-local units.
    let surfaceRadius: Float

    /// Blend from the radial normal to the generated terrain normal in `0...1`.
    let surfaceNormalStrength: Float

    /// Radius of the translucent cloud shell in model-local units.
    let cloudRadius: Float

    /// Outer radius of the atmosphere shell in model-local units.
    let atmosphereRadius: Float

    /// Maximum generated opacity of the cloud layer in `0...1`.
    let cloudOpacity: Float

    /// Nonnegative multiplier applied to atmosphere scattering.
    let atmosphereIntensity: Float

    /// Maximum direct-light attenuation from cloud coverage in `0...1`.
    let cloudShadowStrength: Float

    init(
        surfaceRecipe: TerrestrialPlanetSurfaceRecipe,
        surfaceRadius: Float,
        surfaceNormalStrength: Float,
        cloudRadius: Float,
        atmosphereRadius: Float,
        cloudOpacity: Float,
        atmosphereIntensity: Float,
        cloudShadowStrength: Float
    ) {
        precondition(
            Self.acceptsRadii(
                surfaceRadius: surfaceRadius,
                cloudRadius: cloudRadius,
                atmosphereRadius: atmosphereRadius
            ),
            "Terrestrial planet radii must be finite, positive, and ordered."
        )
        precondition(
            Self.acceptsUnitFactor(surfaceNormalStrength),
            "Terrestrial planet normal strength must be finite and in 0...1."
        )
        precondition(
            Self.acceptsUnitFactor(cloudOpacity),
            "Terrestrial planet cloud opacity must be finite and in 0...1."
        )
        precondition(
            Self.acceptsNonnegativeFactor(atmosphereIntensity),
            "Terrestrial planet atmosphere intensity must be finite and nonnegative."
        )
        precondition(
            Self.acceptsUnitFactor(cloudShadowStrength),
            "Terrestrial planet cloud shadow strength must be finite and in 0...1."
        )

        self.surfaceRecipe = surfaceRecipe
        self.surfaceRadius = surfaceRadius
        self.surfaceNormalStrength = surfaceNormalStrength
        self.cloudRadius = cloudRadius
        self.atmosphereRadius = atmosphereRadius
        self.cloudOpacity = cloudOpacity
        self.atmosphereIntensity = atmosphereIntensity
        self.cloudShadowStrength = cloudShadowStrength
    }

    /// Whether the opaque surface, clouds, and atmosphere form finite nested shells.
    static func acceptsRadii(
        surfaceRadius: Float,
        cloudRadius: Float,
        atmosphereRadius: Float
    ) -> Bool {
        surfaceRadius.isFinite
            && surfaceRadius > 0
            && cloudRadius.isFinite
            && cloudRadius > surfaceRadius
            && atmosphereRadius.isFinite
            && atmosphereRadius > cloudRadius
    }

    /// Whether a scalar satisfies the complete finite `0...1` contract.
    static func acceptsUnitFactor(_ value: Float) -> Bool {
        value.isFinite && value >= 0 && value <= 1
    }

    /// Whether a scalar is finite and nonnegative.
    static func acceptsNonnegativeFactor(_ value: Float) -> Bool {
        value.isFinite && value >= 0
    }
}
