import simd

/// Backend-neutral factors for one authored opaque PBR material.
///
/// Game Content constructs these descriptions and supplies them through the
/// Render-owned catalog contract. The description contains finite scene-linear
/// values only: it owns no texture, buffer, GPU address, pipeline, or other
/// backend resource. Render privately converts it into the representation used
/// by the current draw path.
nonisolated struct PBRMaterialDescription: Equatable, Sendable {
    /// Scene-linear RGB reflectance in the closed `0...1` interval.
    let baseColor: SIMD3<Float>

    /// Metallic blend factor in the closed `0...1` interval.
    let metallic: Float

    /// Authored perceptual roughness in the closed `0...1` interval.
    ///
    /// The shared BRDF owns its documented evaluation floor; this contract
    /// preserves the authored value rather than baking renderer policy into
    /// Game Content.
    let perceptualRoughness: Float

    init(
        baseColor: SIMD3<Float>,
        metallic: Float,
        perceptualRoughness: Float
    ) {
        // Reject invalid authored content at construction instead of allowing a
        // later shader clamp to silently change the requested appearance.
        precondition(
            Self.acceptsBaseColor(baseColor),
            "PBR base-color channels must be finite scene-linear values in 0...1."
        )
        precondition(
            Self.acceptsUnitFactor(metallic),
            "PBR metallic must be a finite value in 0...1."
        )
        precondition(
            Self.acceptsUnitFactor(perceptualRoughness),
            "PBR perceptual roughness must be a finite value in 0...1."
        )

        self.baseColor = baseColor
        self.metallic = metallic
        self.perceptualRoughness = perceptualRoughness
    }

    /// Whether every scene-linear base-color channel is legal authored input.
    ///
    /// Keeping this predicate independently testable locks the precondition's
    /// treatment of every vector lane without introducing a second initializer
    /// or a recoverable runtime fallback for malformed static Game Content.
    static func acceptsBaseColor(_ value: SIMD3<Float>) -> Bool {
        acceptsUnitFactor(value.x)
            && acceptsUnitFactor(value.y)
            && acceptsUnitFactor(value.z)
    }

    /// Whether a scalar satisfies the complete finite `0...1` contract.
    ///
    /// The explicit finite check matters because NaN fails both range
    /// comparisons in ways that can otherwise be easy to overlook in review.
    static func acceptsUnitFactor(_ value: Float) -> Bool {
        value.isFinite && value >= 0 && value <= 1
    }
}
