import simd

/// Test-only mirror of the isolated proof shader's provisional 64-byte input.
///
/// The four explicit SIMD lanes make Swift/Metal alignment inspectable without
/// implying the material or light binding that Milestone 4 will eventually
/// design. Values are validated in their semantic domain before being packed.
struct PBRProofParameters {
    var baseColorMetallic: SIMD4<Float>
    var directionToLightRoughness: SIMD4<Float>
    var lightColorIntensity: SIMD4<Float>
    var directionToCameraPadding: SIMD4<Float>

    /// Renderer-owned constants used when a test does not need a variant.
    static let validation = PBRProofParameters(
        baseColor: SIMD3<Float>(0.5, 0.25, 0.125),
        metallic: 0,
        perceptualRoughness: 0.5,
        directionToLightWorld: SIMD3<Float>(0, 0, 1),
        lightColor: SIMD3<Float>(repeating: 1),
        lightIntensity: 1,
        directionToCameraView: SIMD3<Float>(0, 0, 1)
    )

    init(
        baseColor: SIMD3<Float>,
        metallic: Float,
        perceptualRoughness: Float,
        directionToLightWorld: SIMD3<Float>,
        lightColor: SIMD3<Float>,
        lightIntensity: Float,
        directionToCameraView: SIMD3<Float>,
        worldToViewRotation: simd_float3x3 = matrix_identity_float3x3
    ) {
        precondition(
            Self.hasOnlyFiniteValues(baseColor)
                && baseColor.x >= 0 && baseColor.x <= 1
                && baseColor.y >= 0 && baseColor.y <= 1
                && baseColor.z >= 0 && baseColor.z <= 1,
            "PBR proof base color must be finite linear RGB in 0...1."
        )
        precondition(
            metallic.isFinite && metallic >= 0 && metallic <= 1,
            "PBR proof metallic must be finite and in 0...1."
        )
        precondition(
            perceptualRoughness.isFinite
                && perceptualRoughness >= 0
                && perceptualRoughness <= 1,
            "PBR proof perceptual roughness must be finite and in 0...1."
        )
        precondition(
            Self.hasOnlyFiniteValues(lightColor)
                && lightColor.x >= 0
                && lightColor.y >= 0
                && lightColor.z >= 0,
            "PBR proof light color must be finite, nonnegative linear RGB."
        )
        precondition(
            lightIntensity.isFinite && lightIntensity >= 0,
            "PBR proof light intensity must be finite and nonnegative."
        )

        // The source direction is defined surface-to-light in world space. A
        // direction uses w=0 semantics, so only the camera rotation participates
        // in this one-per-proof transformation into view space.
        let directionToLightView = worldToViewRotation * directionToLightWorld
        let normalizedLightDirection = Self.normalizedFiniteDirection(
            directionToLightView,
            label: "surface-to-light"
        )
        let normalizedCameraDirection = Self.normalizedFiniteDirection(
            directionToCameraView,
            label: "surface-to-camera"
        )

        self.baseColorMetallic = SIMD4<Float>(
            baseColor.x,
            baseColor.y,
            baseColor.z,
            metallic
        )
        self.directionToLightRoughness = SIMD4<Float>(
            normalizedLightDirection.x,
            normalizedLightDirection.y,
            normalizedLightDirection.z,
            perceptualRoughness
        )
        self.lightColorIntensity = SIMD4<Float>(
            lightColor.x,
            lightColor.y,
            lightColor.z,
            lightIntensity
        )
        self.directionToCameraPadding = SIMD4<Float>(
            normalizedCameraDirection.x,
            normalizedCameraDirection.y,
            normalizedCameraDirection.z,
            0
        )
    }

    private static func normalizedFiniteDirection(
        _ direction: SIMD3<Float>,
        label: StaticString
    ) -> SIMD3<Float> {
        let lengthSquared = simd_length_squared(direction)
        precondition(
            Self.hasOnlyFiniteValues(direction)
                && lengthSquared.isFinite
                && lengthSquared > 0,
            "PBR proof \(label) direction must be finite and nonzero."
        )
        return direction / sqrt(lengthSquared)
    }

    private static func hasOnlyFiniteValues(
        _ value: SIMD3<Float>
    ) -> Bool {
        value.x.isFinite && value.y.isFinite && value.z.isFinite
    }
}
