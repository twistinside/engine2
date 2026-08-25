/// Scheduled simulation logic that advances authoritative world state.
///
/// Systems belong inside the Simulation Runtime and run in the order chosen by
/// `Engine`; they are not top-level runtimes. Implementations should iterate
/// component stores directly and use in-place component updates for existing
/// rows. The mutating requirement also permits value-type systems to retain
/// deliberately scoped scheduling state. `deltaTime` is the invocation's
/// authoritative world interval in double-precision seconds. The selected
/// ``SimulationTimeScale`` may make it larger than the nominal base interval.
protocol PSystem {
    mutating func update(world: inout World, deltaTime: Double)
}
