/// Authoritative world-space position for one entity.
///
/// The value is stored in `World.positionComponents`; positioned entity
/// facades read this row live, and simulation systems mutate the store directly.
/// Coordinates use double-precision meters.
struct CPosition: PComponent {
    var position: SIMD3<Double>
}
