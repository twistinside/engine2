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

    /// Exact Simulation publication projected into this frame, when present.
    var sourceCursor: SimulationCursor? {
        provenance.sourceCursor
    }

    /// Explicit Render-owned viewpoint used for exact request projection.
    var viewpointID: RenderViewpointID? {
        provenance.viewpointID
    }

    /// Revision of the explicit Render-owned viewpoint used for projection.
    var viewpointRevision: RenderViewpointRevision? {
        provenance.viewpointRevision
    }

    /// Tick-only migration view for consumers confined to one known session.
    var sourceTick: SimulationTick? {
        sourceCursor?.tick
    }

    /// Projects publisher-owned presentation facts for the live screen.
    ///
    /// The Simulation publication is the complete authority for both scene and
    /// camera state on this path. Output-selected viewpoints are accepted only
    /// by the exact request initializer used for deliberate offscreen work.
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
            // Screen presentation is intentionally tolerant. Reuse the exact
            // per-entity validator, then omit only the malformed instance so a
            // later good snapshot can continue presenting.
            try? RenderInstance(projecting: entity, viewMatrix: viewMatrix)
        }

        self.init(
            provenance: .simulation(sourceCursor: snapshot.cursor),
            camera: camera,
            instances: instances
        )
    }

    /// Projects every requested presentation fact or reports why it cannot.
    ///
    /// Unlike the screen-oriented tolerant projection, this exact boundary
    /// never converts malformed input into an empty or partial success. The
    /// first invalid entity is reported with its authoritative `EntityID`.
    init(exactlyProjecting snapshot: SimulationPresentationSnapshot, viewpoint: RenderViewpoint) throws {
        guard viewpoint.camera.supportsViewTransform else {
            throw RenderFrameProjectionError.invalidSelectedCamera
        }

        let viewMatrix = viewpoint.camera.viewMatrix
        let instances = try snapshot.entityPresentations.map { entity in
            try RenderInstance(projecting: entity, viewMatrix: viewMatrix)
        }

        self.init(
            provenance: .exact(
                sourceCursor: snapshot.cursor,
                viewpointID: viewpoint.id,
                viewpointRevision: viewpoint.revision
            ),
            camera: viewpoint.camera,
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
