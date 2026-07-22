import simd

/// Render Runtime-owned projection for one simulation presentation snapshot.
struct RenderFrame: Equatable {
    static let empty = RenderFrame(
        sourceCursor: nil,
        viewpointID: nil,
        viewpointRevision: nil,
        camera: Camera(),
        instances: []
    )

    /// Exact Simulation publication projected into this frame, when present.
    let sourceCursor: SimulationCursor?
    /// Explicit Render-owned viewpoint used for projection, when one overrides the snapshot camera.
    let viewpointID: RenderViewpointID?
    /// Revision of the explicit Render-owned viewpoint used for projection.
    let viewpointRevision: RenderViewpointRevision?
    let camera: Camera
    let instances: [RenderInstance]

    /// Tick-only migration view for consumers confined to one known session.
    var sourceTick: SimulationTick? {
        sourceCursor?.tick
    }

    /// Projects publisher-owned presentation facts into private render data.
    static func project(
        from snapshot: SimulationPresentationSnapshot,
        viewpoint: RenderViewpoint? = nil
    ) -> RenderFrame {
        let camera = viewpoint?.camera ?? snapshot.camera

        // An invalid camera would poison every model-view transform. Preserve
        // the selected camera value and its provenance for inspection, but
        // produce a safe empty frame rather than sending NaN positions or
        // normals to the GPU.
        guard camera.supportsViewTransform else {
            return RenderFrame(
                sourceCursor: snapshot.cursor,
                viewpointID: viewpoint?.id,
                viewpointRevision: viewpoint?.revision,
                camera: camera,
                instances: []
            )
        }

        let viewMatrix = camera.viewMatrix
        let instances = snapshot.entityPresentations.compactMap { entity in
            // Screen presentation is intentionally tolerant. Reuse the exact
            // per-entity validator, then omit only the malformed instance so a
            // later good snapshot can continue presenting.
            try? projectInstance(entity, viewMatrix: viewMatrix)
        }

        return RenderFrame(
            sourceCursor: snapshot.cursor,
            viewpointID: viewpoint?.id,
            viewpointRevision: viewpoint?.revision,
            camera: camera,
            instances: instances
        )
    }

    /// Projects every requested presentation fact or reports why it cannot.
    ///
    /// Unlike the screen-oriented tolerant projection, this exact boundary
    /// never converts malformed input into an empty or partial success. The
    /// first invalid entity is reported with its authoritative `EntityID`.
    static func projectExact(
        from snapshot: SimulationPresentationSnapshot,
        viewpoint: RenderViewpoint
    ) throws -> RenderFrame {
        guard viewpoint.camera.supportsViewTransform else {
            throw RenderFrameProjectionError.invalidSelectedCamera
        }

        let viewMatrix = viewpoint.camera.viewMatrix
        let instances = try snapshot.entityPresentations.map { entity in
            try projectInstance(entity, viewMatrix: viewMatrix)
        }

        return RenderFrame(
            sourceCursor: snapshot.cursor,
            viewpointID: viewpoint.id,
            viewpointRevision: viewpoint.revision,
            camera: viewpoint.camera,
            instances: instances
        )
    }

    /// Validates and projects one entity for both tolerant and exact callers.
    private static func projectInstance(
        _ entity: EntityPresentationSnapshot,
        viewMatrix: simd_float4x4
    ) throws -> RenderInstance {
        guard let position = entity.position else {
            throw RenderFrameProjectionError.missingPosition(
                entityID: entity.id
            )
        }

        let instance = RenderInstance(
            meshID: entity.meshID,
            materialID: entity.materialID,
            transform: Transform(
                position: position,
                rotation: entity.rotation ?? Transform.identityRotation,
                scale: entity.scale ?? RenderInstance.defaultScale
            )
        )

        // A singular transform cannot provide the inverse-transpose matrix
        // required by the normal path. Exact callers need the offending entity
        // instead of the tolerant screen path's omission.
        guard instance.transform.supportsNormalTransform else {
            throw RenderFrameProjectionError.unsupportedNormalTransform(
                entityID: entity.id
            )
        }

        // Finite camera and model transforms can still overflow together.
        // Validate the actual product consumed by `GPUInstance`.
        let modelViewMatrix = viewMatrix * instance.transform.matrix
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

        return instance
    }
}

/// Render-owned projection of one entity's abstract presentation state.
///
/// Mesh and material identities remain backend-neutral here. Later Render
/// stages privately resolve them without exposing descriptions or GPU resources
/// to the Simulation-owned source snapshot.
struct RenderInstance: Equatable {
    /// Default world-space size for renderable entities that do not advertise scale yet.
    static let defaultScale = SIMD3<Float>(repeating: 0.5)

    let meshID: MeshID
    let materialID: MaterialID
    let transform: Transform

    init(
        meshID: MeshID,
        materialID: MaterialID,
        transform: Transform
    ) {
        self.meshID = meshID
        self.materialID = materialID
        self.transform = transform
    }

    init(
        meshID: MeshID,
        materialID: MaterialID,
        worldPosition: SIMD3<Float>,
        rotation: simd_quatf = Transform.identityRotation,
        scale: SIMD3<Float> = defaultScale
    ) {
        self.meshID = meshID
        self.materialID = materialID
        self.transform = Transform(
            position: worldPosition,
            rotation: rotation,
            scale: scale
        )
    }
}
