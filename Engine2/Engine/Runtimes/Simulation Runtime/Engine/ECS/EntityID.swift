/// Generational handle that identifies one logical entity within a `World`.
///
/// The sparse-set lookup begins with `index` for speed, then validates the full
/// value so a stale handle cannot resolve a newer entity that eventually reuses
/// the same slot. World reservations remain monotonic; destruction compacts
/// component stores without reusing indices or incrementing generations.
///
/// Comparison orders index before generation for deterministic structural
/// enumeration and tie-breaking. It does not represent creation chronology or
/// gameplay priority.
nonisolated struct EntityID: Codable, Hashable, Sendable {
    let index: Int
    let generation: Int
}

extension EntityID: Comparable {
    static func < (lhs: Self, rhs: Self) -> Bool {
        if lhs.index == rhs.index {
            return lhs.generation < rhs.generation
        }
        return lhs.index < rhs.index
    }
}
