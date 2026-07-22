/// Exact projection failure caused by malformed presentation input.
///
/// Live screen rendering may omit malformed entities to keep presenting later
/// snapshots. Exact consumers instead receive the first rejected fact with its
/// Simulation-owned entity identity so they cannot mistake a partial frame for
/// a faithful rendering of the requested snapshot.
nonisolated enum RenderFrameProjectionError: Error, Equatable, Sendable {
    /// The selected camera cannot produce a finite world-to-view transform.
    case invalidSelectedCamera

    /// A presented entity has no world-space position to render.
    case missingPosition(entityID: EntityID)

    /// An entity transform cannot produce finite positions and normals.
    case unsupportedNormalTransform(entityID: EntityID)

    /// Individually valid camera and model transforms overflow when combined.
    case nonfiniteModelViewTransform(entityID: EntityID)

    /// The output projection overflows only after applying one model-view transform.
    case nonfiniteModelViewProjectionTransform(entityID: EntityID)
}
