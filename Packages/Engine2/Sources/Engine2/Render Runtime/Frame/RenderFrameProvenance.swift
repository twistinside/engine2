/// Complete attribution for one private Render projection.
///
/// Live Simulation projection and exact output projection carry different
/// provenance. Associated values keep viewpoint identity and revision together
/// and prevent either from existing without the Simulation cursor it qualifies.
enum RenderFrameProvenance: Equatable {
    /// Placeholder frame that does not claim a Simulation publication.
    case empty

    /// Latest-value screen projection using the Simulation-authored camera.
    case simulation(sourceCursor: SimulationCursor)

    /// Exact output projection using one explicit Render-owned viewpoint.
    case exact(
        sourceCursor: SimulationCursor,
        viewpointID: RenderViewpointID,
        viewpointRevision: RenderViewpointRevision
    )

    /// Exact Simulation publication projected into the frame, when present.
    var sourceCursor: SimulationCursor? {
        switch self {
        case .empty:
            nil

        case let .simulation(sourceCursor),
             let .exact(sourceCursor, _, _):
            sourceCursor
        }
    }

    /// Explicit Render-owned viewpoint identity used by exact projection.
    var viewpointID: RenderViewpointID? {
        guard case let .exact(_, viewpointID, _) = self else {
            return nil
        }
        return viewpointID
    }

    /// Explicit Render-owned viewpoint revision used by exact projection.
    var viewpointRevision: RenderViewpointRevision? {
        guard case let .exact(_, _, viewpointRevision) = self else {
            return nil
        }
        return viewpointRevision
    }
}
