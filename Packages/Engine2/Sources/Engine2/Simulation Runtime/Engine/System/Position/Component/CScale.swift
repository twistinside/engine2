/// Authoritative per-axis scale for one entity.
///
/// Capability-driven registration defaults this value to unit scale. Render
/// extraction can carry it across a snapshot boundary without exposing the
/// component store itself.
struct CScale: PComponent {
    let scale: SIMD3<Float>
}
