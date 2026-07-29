import Engine2GPUABI
import simd

extension PBRSceneParameters {
    static let validationDirectionToLightWorld = SIMD3<Float>(0, 0, 1)
    static let validationLightColor = SIMD3<Float>(1, 0.5, 0.25)
    static let validationLightIntensity: Float = 8

    /// Resolves the fixed validation light into the shared raw GPU record.
    ///
    /// The light direction follows the direct-light BRDF convention:
    /// surface-to-light in view space.
    init(camera: Camera) {
        precondition(camera.supportsViewTransform, "PBR scene parameters require a finite camera transform.")

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

        self.init()
        self.directionToLightPadding = SIMD4<Float>(
            directionToLightView.x,
            directionToLightView.y,
            directionToLightView.z,
            0
        )
        self.lightColorIntensity = SIMD4<Float>(
            Self.validationLightColor.x,
            Self.validationLightColor.y,
            Self.validationLightColor.z,
            Self.validationLightIntensity
        )
    }
}
