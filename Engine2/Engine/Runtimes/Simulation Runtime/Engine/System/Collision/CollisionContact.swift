/// Immutable geometric contact between two collision bodies during one Simulation tick.
///
/// Complete entity identity orders the pair. The normal points from the second body toward the first.
/// The fraction measures elapsed time against the complete tick, including lifetime-clipped sweeps.
/// World retains initial contacts until final collection; response systems apply their own gameplay policy.
struct CollisionContact {
    let firstEntityID: EntityID
    let secondEntityID: EntityID
    let tickFraction: Double
    let normal: SIMD2<Double>
}
