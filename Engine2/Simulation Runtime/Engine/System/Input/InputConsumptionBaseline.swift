import simd

/// Cumulative input totals last accepted by one Simulation consumer.
///
/// Revision and totals form one baseline: none of them is meaningful without
/// the others. The uninitialized case lets the first publication apply totals
/// from the beginning of its Input Runtime session.
nonisolated enum InputConsumptionBaseline: Equatable, Sendable {
    case uninitialized
    case consumed(
        revision: InputRevision,
        pointerMotionTotal: SIMD2<Float>,
        scrollTotal: SIMD2<Float>
    )
}
