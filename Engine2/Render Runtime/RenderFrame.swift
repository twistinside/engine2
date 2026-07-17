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
        let instances = snapshot.entityPresentations.compactMap { entity -> RenderInstance? in
            guard let position = entity.position else {
                return nil
            }

            return RenderInstance(
                meshID: entity.meshID,
                transform: Transform(
                    position: position,
                    rotation: entity.rotation ?? Transform.identityRotation,
                    scale: entity.scale ?? RenderInstance.defaultScale
                )
            )
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
