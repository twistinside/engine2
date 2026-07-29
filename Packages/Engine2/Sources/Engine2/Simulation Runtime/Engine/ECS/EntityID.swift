/// Generational handle that identifies one logical entity within a `World`.
///
/// The sparse-set lookup begins with `index` for speed, then validates the full
/// value so a stale handle cannot resolve a newer entity that eventually reuses
/// the same slot. Index reuse is intentionally deferred until destruction and
/// dense-store compaction preserve this generation invariant.
public nonisolated struct EntityID: Hashable, Sendable {
    public let index: Int
    public let generation: Int

    public init(index: Int, generation: Int) {
        self.index = index
        self.generation = generation
    }
}
