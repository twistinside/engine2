import simd

/// Render Runtime-owned projection for one simulation presentation snapshot.
struct RenderFrame: Equatable {
    static let empty = RenderFrame(
        sourceTick: .zero,
        camera: Camera(),
        instances: []
    )

    let sourceTick: SimulationTick
    let camera: Camera
    let instances: [RenderInstance]

    /// Projects publisher-owned presentation facts into private render data.
    static func project(
        from snapshot: SimulationPresentationSnapshot
    ) -> RenderFrame {
        // An invalid camera would poison every model-view transform. Preserve
        // the published camera value for inspection, but produce a safe empty
        // frame rather than sending NaN positions or normals to the GPU.
        guard snapshot.camera.supportsViewTransform else {
            return RenderFrame(
                sourceTick: snapshot.tick,
                camera: snapshot.camera,
                instances: []
            )
        }

        let viewMatrix = snapshot.camera.viewMatrix
        let instances = snapshot.entityPresentations.compactMap { entity -> RenderInstance? in
            guard let position = entity.position else {
                return nil
            }

            let instance = RenderInstance(
                meshID: entity.meshID,
                transform: Transform(
                    position: position,
                    rotation: entity.rotation ?? Transform.identityRotation,
                    scale: entity.scale ?? RenderInstance.defaultScale
                )
            )

            // Rendering a singular transform would require inverting a zero
            // scale to transform normals. Omit malformed presentation data at
            // this private projection boundary instead of publishing NaNs to
            // the GPU or changing authoritative Simulation state.
            guard instance.transform.supportsNormalTransform else {
                return nil
            }

            // A camera and model can each be finite independently while their
            // combined translations overflow. Validate their actual product so
            // accepted instances are safe for both the position and normal
            // paths used by `GPUInstance`.
            guard (viewMatrix * instance.transform.matrix).hasFiniteElements else {
                return nil
            }

            return instance
        }

        return RenderFrame(
            sourceTick: snapshot.tick,
            camera: snapshot.camera,
            instances: instances
        )
    }
}

/// Minimal per-entity presentation state.
struct RenderInstance: Equatable {
    /// Default world-space size for renderable entities that do not advertise scale yet.
    static let defaultScale = SIMD3<Float>(repeating: 0.5)

    let meshID: MeshID
    let transform: Transform

    init(meshID: MeshID, transform: Transform) {
        self.meshID = meshID
        self.transform = transform
    }

    init(
        meshID: MeshID,
        worldPosition: SIMD3<Float>,
        rotation: simd_quatf = Transform.identityRotation,
        scale: SIMD3<Float> = defaultScale
    ) {
        self.meshID = meshID
        self.transform = Transform(
            position: worldPosition,
            rotation: rotation,
            scale: scale
        )
    }
}
