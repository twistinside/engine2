import Engine2
import Engine2AssemblySupport
import Engine2OfflineCaptureAssembly
/// Exact Simulation scene source selected by one agent capture request.
///
/// Advancing requests commit a positive bounded batch before capture. Current
/// requests verify and render the already completed cursor without mutating
/// Simulation. The source is part of request equality, so changing either the
/// operation or its expected cursor under one request identity is a conflict.
public nonisolated enum AgentCaptureSource: Equatable, Sendable {
    case advance(expectedCursor: SimulationCursor, stepCount: SimulationStepCount)
    case current(expectedCursor: SimulationCursor)

    /// Cursor whose completed presentation the request is allowed to use.
    public var expectedCursor: SimulationCursor {
        switch self {
        case let .advance(expectedCursor, _),
             let .current(expectedCursor):
            expectedCursor
        }
    }
}
