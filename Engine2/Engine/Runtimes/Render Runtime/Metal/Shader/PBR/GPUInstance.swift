import simd

extension GPUInstance {
    /// Derives one raw GPU record from a validated Render instance and its authored material.
    ///
    /// Transform fields support rasterization and view-space lighting. The final two lanes are
    /// Render's private GPU representation of the material and remain separate from ECS and Game Content.
    init(_ instance: RenderInstance, material: PBRMaterialDescription, projectionMatrix: simd_float4x4) {
        // Initialize the imported record before assigning its fields so any padding-only lanes start deterministically.
        self.init()
        self.modelViewProjectionMatrix = projectionMatrix * instance.modelViewMatrix
        self.modelViewMatrix = instance.modelViewMatrix
        self.normalMatrix = instance.normalMatrix
        self.baseColorMetallic = SIMD4<Float>(
            material.baseColor.x,
            material.baseColor.y,
            material.baseColor.z,
            material.metallic
        )
        self.perceptualRoughnessPadding = SIMD4<Float>(
            material.perceptualRoughness,
            0,
            0,
            0
        )
    }
}
