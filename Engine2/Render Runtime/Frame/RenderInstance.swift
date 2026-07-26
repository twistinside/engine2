import simd

/// Render-owned projection of one entity's abstract presentation state.
///
/// Mesh and material identities remain backend-neutral here. Later Render
/// stages privately resolve them without exposing descriptions or GPU resources
/// to the Simulation-owned source snapshot.
struct RenderInstance: Equatable {
    /// Missing-scale projection policy for renderable entities without scale state.
    static let defaultScale = SIMD3<Float>(repeating: 0.5)

    let meshID: MeshID
    let materialID: MaterialID
    let transform: Transform
}

extension RenderInstance {
    /// Validates and projects one entity through a selected camera view.
    ///
    /// The initializer lives in an extension so Swift can still synthesize the
    /// direct memberwise initializer used for already-projected Render values.
    init(projecting entity: EntityPresentationSnapshot, viewMatrix: simd_float4x4) throws(RenderFrameProjectionError) {
        guard let position = entity.position else {
            throw RenderFrameProjectionError.missingPosition(
                entityID: entity.id
            )
        }

        let transform = Transform(
            position: position,
            rotation: entity.rotation ?? Transform.identityRotation,
            scale: entity.scale ?? Self.defaultScale
        )

        // A singular transform cannot provide the inverse-transpose matrix
        // required by the normal path. Exact callers need the offending entity
        // instead of the tolerant screen path's omission.
        guard transform.supportsNormalTransform else {
            throw RenderFrameProjectionError.unsupportedNormalTransform(
                entityID: entity.id
            )
        }

        // Finite camera and model transforms can still overflow together.
        // Validate the actual product consumed by `GPUInstance`.
        let modelViewMatrix = viewMatrix * transform.matrix
        guard modelViewMatrix.hasFiniteElements else {
            throw RenderFrameProjectionError.nonfiniteModelViewTransform(
                entityID: entity.id
            )
        }

        // Extremely small but individually representable scales can still
        // collapse the combined linear transform, while an ill-conditioned
        // inverse can overflow. Validate the exact normal-matrix operation
        // before `GPUInstance` performs it under a precondition.
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
        let determinant = simd_determinant(linearModelView)
        let inverse = simd_inverse(linearModelView)
        guard determinant.isFinite,
              determinant != 0,
              [inverse.columns.0, inverse.columns.1, inverse.columns.2]
                .allSatisfy({ column in
                    column.x.isFinite
                        && column.y.isFinite
                        && column.z.isFinite
                })
        else {
            throw RenderFrameProjectionError.unsupportedNormalTransform(
                entityID: entity.id
            )
        }

        self.init(
            meshID: entity.meshID,
            materialID: entity.materialID,
            transform: transform
        )
    }
}
