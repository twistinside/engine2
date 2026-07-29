/// Immutable, backend-neutral camera selection for one render output.
///
/// Identity distinguishes independently controlled outputs, while revision
/// distinguishes changes to one output's own state. If the camera is a resolved
/// Simulation default, its source cursor supplies the complementary attribution.
public nonisolated struct RenderViewpoint: Equatable, Sendable {
    public let id: RenderViewpointID
    public let revision: RenderViewpointRevision
    public let camera: Camera

    public init(
        id: RenderViewpointID,
        revision: RenderViewpointRevision,
        camera: Camera
    ) {
        self.id = id
        self.revision = revision
        self.camera = camera
    }
}
