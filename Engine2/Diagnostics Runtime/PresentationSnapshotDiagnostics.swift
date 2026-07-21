/// Completed timing and scale facts for Simulation presentation publication.
struct PresentationSnapshotDiagnostics: Codable, Equatable, Sendable {
    let tick: SimulationTick
    let renderableRowCount: Int
    let publishedPresentationCount: Int
    let durationNanoseconds: UInt64
}
