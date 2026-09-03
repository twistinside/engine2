/// Render Runtime-owned projection for one simulation presentation snapshot.
struct RenderFrame: Equatable {
    static let empty = RenderFrame(
        provenance: .empty,
        camera: .standard,
        instances: []
    )

    let provenance: RenderFrameProvenance
    let camera: Camera
    let instances: [RenderInstance]

    /// Simulation publication projected into this frame, when present.
    var sourceCursor: SimulationCursor? {
        provenance.sourceCursor
    }

    /// Projects publisher-owned presentation facts for the live screen.
    ///
    /// The Simulation publication is the complete authority for both scene and
    /// camera state.
    init(projecting snapshot: SimulationPresentationSnapshot) {
        let camera = snapshot.camera

        // An invalid camera would poison every model-view transform. Preserve
        // the selected camera value and its provenance for inspection, but
        // produce a safe empty frame rather than sending NaN positions or
        // normals to the GPU.
        guard camera.supportsViewTransform else {
            self.init(
                provenance: .simulation(sourceCursor: snapshot.cursor),
                camera: camera,
                instances: []
            )
            return
        }

        let viewMatrix = camera.viewMatrix
        let instances = snapshot.entityPresentations.compactMap { entity in
            // Screen presentation is intentionally tolerant. Reuse the
            // per-entity validator, then omit only the malformed instance so a
            // later good snapshot can continue presenting.
            RenderInstance(projecting: entity, viewMatrix: viewMatrix)
        }

        self.init(
            provenance: .simulation(sourceCursor: snapshot.cursor),
            camera: camera,
            instances: instances
        )
    }

    /// Stores an already projected frame without changing its attribution.
    private init(
        provenance: RenderFrameProvenance,
        camera: Camera,
        instances: [RenderInstance]
    ) {
        self.provenance = provenance
        self.camera = camera
        self.instances = instances
    }
}
