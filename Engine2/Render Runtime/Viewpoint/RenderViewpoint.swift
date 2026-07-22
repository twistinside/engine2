/// Immutable, backend-neutral camera selection for one render output.
///
/// Identity distinguishes independently controlled outputs, while revision
/// distinguishes changes to one output's own state. If the camera is a resolved
/// Simulation default, its source cursor supplies the complementary attribution.
nonisolated struct RenderViewpoint: Equatable, Sendable {
    let id: RenderViewpointID
    let revision: RenderViewpointRevision
    let camera: Camera
}
