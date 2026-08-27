/// Generational handle that identifies one logical entity within a `World`.
///
/// The sparse-set lookup begins with `index` for speed, then validates the full
/// value so a stale handle cannot resolve a newer entity that eventually reuses
/// the same slot. Index reuse is intentionally deferred until destruction and
/// dense-store compaction preserve this generation invariant.
///
/// Comparison orders index before generation for deterministic structural
/// enumeration and tie-breaking. It does not represent creation chronology or
/// gameplay priority.
nonisolated struct EntityID: Codable, Comparable, Hashable, Sendable {
    let index: Int
    let generation: Int

    static func < (lhs: Self, rhs: Self) -> Bool {
        if lhs.index == rhs.index {
            return lhs.generation < rhs.generation
        }
        return lhs.index < rhs.index
    }
}
