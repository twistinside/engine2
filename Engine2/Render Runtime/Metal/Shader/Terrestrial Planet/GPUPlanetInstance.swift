import simd

extension GPUPlanetInstance {
    /// Fixed world-space direction from a surface point toward the proof sun.
    static let proofDirectionToLightWorld = simd_normalize(
        SIMD3<Float>(0.08, 0.10, 0.99)
    )

    /// Packs one validated planet instance for deterministic GPU evaluation.
    init(
        _ instance: RenderInstance,
        description: TerrestrialPlanetDescription,
        projectionMatrix: simd_float4x4,
        camera: Camera
    ) {
        precondition(
            camera.supportsViewTransform,
            "Terrestrial-planet GPU instances require a finite camera transform."
        )

        let directionToLightWorld = Self.proofDirectionToLightWorld
        let directionToLightWorld4 = SIMD4<Float>(
            directionToLightWorld.x,
            directionToLightWorld.y,
            directionToLightWorld.z,
            0
        )
        let directionToLightView4 = camera.viewMatrix
            * directionToLightWorld4
        let directionToLightView = simd_normalize(
            SIMD3<Float>(
                directionToLightView4.x,
                directionToLightView4.y,
                directionToLightView4.z
            )
        )
        let directionToLightLocal4 = simd_inverse(
            instance.transform.matrix
        ) * directionToLightWorld4
        let directionToLightLocal = simd_normalize(
            SIMD3<Float>(
                directionToLightLocal4.x,
                directionToLightLocal4.y,
                directionToLightLocal4.z
            )
        )

        self.init()
        self.modelViewProjectionMatrix = projectionMatrix
            * instance.modelViewMatrix
        self.modelViewMatrix = instance.modelViewMatrix
        self.normalMatrix = instance.normalMatrix
        self.surfaceCloudAtmosphereNormalStrength = SIMD4<Float>(
            description.surfaceRadius,
            description.cloudRadius,
            description.atmosphereRadius,
            description.surfaceNormalStrength
        )
        self.cloudAtmosphereParameters = SIMD4<Float>(
            description.cloudOpacity,
            description.atmosphereIntensity,
            description.cloudShadowStrength,
            0
        )
        self.directionToLightViewPadding = SIMD4<Float>(
            directionToLightView.x,
            directionToLightView.y,
            directionToLightView.z,
            0
        )
        self.directionToLightLocalPadding = SIMD4<Float>(
            directionToLightLocal.x,
            directionToLightLocal.y,
            directionToLightLocal.z,
            0
        )
    }
}
