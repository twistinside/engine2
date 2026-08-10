/// Immutable authored inputs for one layered terrestrial-planet material.
///
/// The description identifies source textures and normalized local-space
/// geometry. Render privately expands one material into its surface, cloud,
/// and atmosphere work while Simulation continues to publish one entity.
nonisolated struct TerrestrialPlanetDescription: Equatable, Sendable {
    let elevationTextureID: TextureID
    let surfaceTextureID: TextureID
    let controlTextureID: TextureID
    let cloudTextureID: TextureID

    /// Radius of the undisplaced opaque surface in model-local units.
    let surfaceRadius: Float

    /// Largest outward terrain displacement in model-local units.
    let maximumRelief: Float

    /// Elevation-map sample that separates ocean from land in `0...1`.
    let seaLevel: Float

    /// Radius of the translucent cloud shell in model-local units.
    let cloudRadius: Float

    /// Outer radius of the atmosphere shell in model-local units.
    let atmosphereRadius: Float

    /// Maximum authored opacity of the cloud layer in `0...1`.
    let cloudOpacity: Float

    /// Nonnegative multiplier applied to atmosphere scattering.
    let atmosphereIntensity: Float

    /// Maximum direct-light attenuation from cloud coverage in `0...1`.
    let cloudShadowStrength: Float

    /// Texture identities required to resolve this material completely.
    var requiredTextureIDs: [TextureID] {
        [
            elevationTextureID,
            surfaceTextureID,
            controlTextureID,
            cloudTextureID
        ]
    }

    init(
        elevationTextureID: TextureID,
        surfaceTextureID: TextureID,
        controlTextureID: TextureID,
        cloudTextureID: TextureID,
        surfaceRadius: Float,
        maximumRelief: Float,
        seaLevel: Float,
        cloudRadius: Float,
        atmosphereRadius: Float,
        cloudOpacity: Float,
        atmosphereIntensity: Float,
        cloudShadowStrength: Float
    ) {
        precondition(
            Self.acceptsDistinctTextureIDs(
                elevationTextureID: elevationTextureID,
                surfaceTextureID: surfaceTextureID,
                controlTextureID: controlTextureID,
                cloudTextureID: cloudTextureID
            ),
            "A terrestrial planet must use one distinct texture for each authored role."
        )
        precondition(
            Self.acceptsRadii(
                surfaceRadius: surfaceRadius,
                maximumRelief: maximumRelief,
                cloudRadius: cloudRadius,
                atmosphereRadius: atmosphereRadius
            ),
            "Terrestrial planet radii must be finite, ordered, and contain the maximum surface relief."
        )
        precondition(Self.acceptsUnitFactor(seaLevel), "Terrestrial planet sea level must be finite and in 0...1.")
        precondition(Self.acceptsUnitFactor(cloudOpacity), "Terrestrial planet cloud opacity must be finite and in 0...1.")
        precondition(
            Self.acceptsNonnegativeFactor(atmosphereIntensity),
            "Terrestrial planet atmosphere intensity must be finite and nonnegative."
        )
        precondition(
            Self.acceptsUnitFactor(cloudShadowStrength),
            "Terrestrial planet cloud shadow strength must be finite and in 0...1."
        )

        self.elevationTextureID = elevationTextureID
        self.surfaceTextureID = surfaceTextureID
        self.controlTextureID = controlTextureID
        self.cloudTextureID = cloudTextureID
        self.surfaceRadius = surfaceRadius
        self.maximumRelief = maximumRelief
        self.seaLevel = seaLevel
        self.cloudRadius = cloudRadius
        self.atmosphereRadius = atmosphereRadius
        self.cloudOpacity = cloudOpacity
        self.atmosphereIntensity = atmosphereIntensity
        self.cloudShadowStrength = cloudShadowStrength
    }

    /// Whether every authored texture role names a distinct source asset.
    static func acceptsDistinctTextureIDs(
        elevationTextureID: TextureID,
        surfaceTextureID: TextureID,
        controlTextureID: TextureID,
        cloudTextureID: TextureID
    ) -> Bool {
        let textureIDs = [
            elevationTextureID,
            surfaceTextureID,
            controlTextureID,
            cloudTextureID
        ]
        return Set(textureIDs).count == textureIDs.count
    }

    /// Whether the opaque surface, maximum relief, clouds, and atmosphere form
    /// finite nested shells with positive radii.
    static func acceptsRadii(
        surfaceRadius: Float,
        maximumRelief: Float,
        cloudRadius: Float,
        atmosphereRadius: Float
    ) -> Bool {
        surfaceRadius.isFinite
            && surfaceRadius > 0
            && maximumRelief.isFinite
            && maximumRelief >= 0
            && cloudRadius.isFinite
            && cloudRadius > surfaceRadius + maximumRelief
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
