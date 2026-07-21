/// Scheduled simulation logic that advances authoritative world state.
///
/// Systems belong inside the Simulation Runtime and run in the order chosen by
/// `Engine`; they are not top-level runtimes. Implementations should iterate
/// component stores directly and use in-place component updates for existing
/// rows. The mutating requirement also permits value-type systems to retain
/// deliberately scoped scheduling state.
protocol PSystem {
    /// Stable identity for invariant schedule diagnostics, when one exists.
    var diagnosticsID: SimulationSystemID? { get }

    /// Work volume already available without an additional component scan.
    func diagnosticsWorkCount(in world: World) -> Int?

    mutating func update(world: inout World, deltaTime: Float)
}

extension PSystem {
    var diagnosticsID: SimulationSystemID? { nil }

    func diagnosticsWorkCount(in world: World) -> Int? { nil }
}
