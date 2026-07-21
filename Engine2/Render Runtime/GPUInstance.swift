import simd

/// CPU-side layout written to the per-frame GPU instance buffer.
///
/// Its fields match `ModelInstance` in `ModelShaders.metal`. The shader needs a
/// complete clip transform for rasterization, a model-view transform for
/// view-space lighting, and an inverse-transpose linear transform so nonuniform
/// entity scale cannot skew surface normals.
struct GPUInstance {
    var modelViewProjectionMatrix: simd_float4x4
    var modelViewMatrix: simd_float4x4
    var normalMatrix: simd_float3x3

    init(
        _ instance: RenderInstance,
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
    }
}
