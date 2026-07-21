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

    init(
        _ instance: RenderInstance,
        material: PBRMaterialDescription,
        viewMatrix: simd_float4x4,
        projectionMatrix: simd_float4x4
    ) {
        // Build model-view once so the position and normal paths use exactly the
        // same model and camera transforms.
        precondition(
            instance.transform.supportsNormalTransform,
            "GPU instances require a finite transform with invertible scale."
        )
        let modelViewMatrix = viewMatrix * instance.transform.matrix
        precondition(
            modelViewMatrix.hasFiniteElements,
            "GPU instances require a finite model-view transform."
        )
        let linearModelView = simd_float3x3(
            columns: (
                SIMD3<Float>(
                    modelViewMatrix.columns.0.x,
                    modelViewMatrix.columns.0.y,
                    modelViewMatrix.columns.0.z
                ),
                SIMD3<Float>(
                    modelViewMatrix.columns.1.x,
                    modelViewMatrix.columns.1.y,
                    modelViewMatrix.columns.1.z
                ),
                SIMD3<Float>(
                    modelViewMatrix.columns.2.x,
                    modelViewMatrix.columns.2.y,
                    modelViewMatrix.columns.2.z
                )
            )
        )
        let linearDeterminant = simd_determinant(linearModelView)
        precondition(
            linearDeterminant.isFinite && linearDeterminant != 0,
            "GPU instances require a finite, invertible model-view transform."
        )

        self.modelViewProjectionMatrix = projectionMatrix * modelViewMatrix
        self.modelViewMatrix = modelViewMatrix
        self.normalMatrix = simd_transpose(simd_inverse(linearModelView))

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
