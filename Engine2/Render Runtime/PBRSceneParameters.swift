import simd

/// Temporary renderer-owned material and directional-light input for M3.
///
/// This 48-byte layout mirrors `PBRSceneParameters.metalh`. It exists only to
/// prove the visible HDR pathway with one stable material and light; Milestone
/// 4 replaces the material lanes with authored Game Content resolution. The
/// direction uses the shared BRDF convention: surface-to-light in view space.
struct PBRSceneParameters {
    static let validationBaseColor = SIMD3<Float>(0.5, 0.25, 0.125)
    static let validationMetallic: Float = 0
    static let validationPerceptualRoughness: Float = 0.5
    static let validationDirectionToLightWorld = SIMD3<Float>(0, 0, 1)
    static let validationLightColor = SIMD3<Float>(1, 0.5, 0.25)
    static let validationLightIntensity: Float = 8

    var baseColorMetallic: SIMD4<Float>
    var directionToLightRoughness: SIMD4<Float>
    var lightColorIntensity: SIMD4<Float>

    /// Resolves the fixed validation input for one completed camera value.
    init(camera: Camera) {
        precondition(
            camera.supportsViewTransform,
            "PBR scene parameters require a finite camera transform."
        )

        // A direction has w=0 semantics, so camera translation must not affect
        // it. Extract only the linear world-to-view rotation and normalize the
        // result once per frame rather than once per fragment.
        let viewMatrix = camera.viewMatrix
        let worldToViewRotation = simd_float3x3(
            columns: (
                SIMD3<Float>(
                    viewMatrix.columns.0.x,
                    viewMatrix.columns.0.y,
                    viewMatrix.columns.0.z
                ),
                SIMD3<Float>(
                    viewMatrix.columns.1.x,
                    viewMatrix.columns.1.y,
                    viewMatrix.columns.1.z
                ),
                SIMD3<Float>(
                    viewMatrix.columns.2.x,
                    viewMatrix.columns.2.y,
                    viewMatrix.columns.2.z
                )
            )
        )
        let directionToLightView = simd_normalize(
            worldToViewRotation * Self.validationDirectionToLightWorld
        )

        self.baseColorMetallic = SIMD4<Float>(
            Self.validationBaseColor.x,
            Self.validationBaseColor.y,
            Self.validationBaseColor.z,
            Self.validationMetallic
        )
        self.directionToLightRoughness = SIMD4<Float>(
            directionToLightView.x,
            directionToLightView.y,
            directionToLightView.z,
            Self.validationPerceptualRoughness
        )
        self.lightColorIntensity = SIMD4<Float>(
            Self.validationLightColor.x,
            Self.validationLightColor.y,
            Self.validationLightColor.z,
            Self.validationLightIntensity
        )
    }
}
