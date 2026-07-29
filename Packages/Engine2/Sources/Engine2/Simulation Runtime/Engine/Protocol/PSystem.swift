/// Scheduled simulation logic that advances authoritative world state.
///
/// Systems belong inside the Simulation Runtime and run in the order chosen by
/// `Engine`; they are not top-level runtimes. Implementations should iterate
/// component stores directly and use in-place component updates for existing
/// rows. The mutating requirement also permits value-type systems to retain
/// deliberately scoped scheduling state.
protocol PSystem {
    mutating func update(world: inout World, deltaTime: Float)
}
