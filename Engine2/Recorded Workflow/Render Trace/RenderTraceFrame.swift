/// One validated, ordered unit of renderer-only trace input.
nonisolated struct RenderTraceFrame: Codable, Equatable, Sendable {
    let sequence: UInt64
    let presentationSnapshot: SimulationPresentationSnapshot
    let projection: RenderTraceFrameProjection
    let settings: OffscreenRenderSettings
    let clearColor: RenderTraceClearColor

    /// Constructs a frame only when every domain value is safe to persist.
    init(
        sequence: UInt64,
        presentationSnapshot: SimulationPresentationSnapshot,
        projection: RenderTraceFrameProjection,
        settings: OffscreenRenderSettings,
        clearColor: RenderTraceClearColor = .opaqueBlack
    ) throws(RenderTraceValidationError) {
        _ = try RenderTraceSnapshotRecord(presentationSnapshot)
        if case let .explicit(viewpoint) = projection {
            _ = try RenderTraceViewpointRecord(viewpoint)
        }
        _ = try RenderTraceSettingsRecord(settings)

        self.sequence = sequence
        self.presentationSnapshot = presentationSnapshot
        self.projection = projection
        self.settings = settings
        self.clearColor = clearColor
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let snapshot = try container.decode(
            RenderTraceSnapshotRecord.self,
            forKey: .presentationSnapshot
        )
        let settings = try container.decode(
            RenderTraceSettingsRecord.self,
            forKey: .settings
        )

        try self.init(
            sequence: container.decode(UInt64.self, forKey: .sequence),
            presentationSnapshot: snapshot.value,
            projection: container.decode(
                RenderTraceFrameProjection.self,
                forKey: .projection
            ),
            settings: settings.value(),
            clearColor: container.decode(
                RenderTraceClearColor.self,
                forKey: .clearColor
            )
        )
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(sequence, forKey: .sequence)
        try container.encode(
            RenderTraceSnapshotRecord(presentationSnapshot),
            forKey: .presentationSnapshot
        )
        try container.encode(projection, forKey: .projection)
        try container.encode(
            RenderTraceSettingsRecord(settings),
            forKey: .settings
        )
        try container.encode(clearColor, forKey: .clearColor)
    }

    /// Resolves the trace-level Simulation camera identity into exact input.
    func renderInput(
        simulationCameraViewpointID: RenderViewpointID
    ) -> RenderTraceRenderInput {
        let viewpoint: RenderViewpoint
        switch projection {
        case .simulationCamera:
            viewpoint = RenderViewpoint(
                id: simulationCameraViewpointID,
                revision: .zero,
                camera: presentationSnapshot.camera
            )

        case let .explicit(explicitViewpoint):
            viewpoint = explicitViewpoint
        }

        return RenderTraceRenderInput(
            sequence: sequence,
            presentationSnapshot: presentationSnapshot,
            viewpoint: viewpoint,
            settings: settings,
            clearColor: clearColor
        )
    }

    private enum CodingKeys: String, CodingKey {
        case sequence
        case presentationSnapshot
        case projection
        case settings
        case clearColor
    }
}
