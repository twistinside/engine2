import simd

/// CPU-side per-draw layout written to the reusable GPU instance buffer.
///
/// Its fields match `ModelInstance` in `ModelShaders.metal`. Transform fields
/// support rasterization and view-space lighting, while the final two lanes are
/// the smallest private GPU representation of one authored PBR material. This
/// keeps material factors beside the draw that consumes them without exposing
/// those factors to ECS or introducing a material buffer or compact index.
struct GPUInstance {
    var modelViewProjectionMatrix: simd_float4x4
    var modelViewMatrix: simd_float4x4
    var normalMatrix: simd_float3x3
    var baseColorMetallic: SIMD4<Float>
    var perceptualRoughnessPadding: SIMD4<Float>

    init(_ instance: RenderInstance, material: PBRMaterialDescription, projectionMatrix: simd_float4x4) {
        self.modelViewProjectionMatrix = projectionMatrix * instance.modelViewMatrix
        self.modelViewMatrix = instance.modelViewMatrix
        self.normalMatrix = instance.normalMatrix

        // Use explicit aligned float4 lanes on both sides of the Swift/Metal
        // boundary. The description remains a semantic CPU value; only this
        // renderer-private record knows how those factors reach the shader.
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
