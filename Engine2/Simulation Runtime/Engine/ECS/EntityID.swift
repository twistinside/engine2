/// Generational handle that identifies one logical entity within a `World`.
///
/// The sparse-set lookup begins with `index` for speed, then validates the full
/// value so a stale handle cannot resolve a newer entity that eventually reuses
/// the same slot. Index reuse is intentionally deferred until destruction and
/// dense-store compaction preserve this generation invariant.
struct EntityID: Hashable {
    let index: Int
    let generation: Int
}
