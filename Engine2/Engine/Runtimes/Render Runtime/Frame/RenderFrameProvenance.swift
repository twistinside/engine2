/// Simulation attribution for one private Render projection.
enum RenderFrameProvenance: Equatable {
    /// Placeholder frame that does not claim a Simulation publication.
    case empty

    /// Screen projection using the Simulation-authored camera.
    case simulation(sourceCursor: SimulationCursor)

    /// Simulation publication projected into the frame, when present.
    var sourceCursor: SimulationCursor? {
        switch self {
        case .empty:
            nil

        case let .simulation(sourceCursor):
            sourceCursor
        }
    }
}
