/// Sparse-set style storage for a single component type.
///
/// Component values live in `dense`, the owning `EntityID`s stay aligned in
/// `entities`, and `sparse` maps an entity index back to the dense slot when a
/// live row exists for that entity generation.
struct ComponentStore<C: Component> {
    private(set) var dense: [C] = []
    private(set) var entities: [EntityID] = []
    private(set) var sparse: [Int: Int] = [:]

    /// Inserts or replaces the component row for an entity.
    ///
    /// Remove the current owner before inserting a different generation at the
    /// same index. This keeps sparse lookup and dense iteration in agreement.
    mutating func insert(_ component: C, for entity: EntityID) {
        if let denseIndex = sparse[entity.index] {
            precondition(
                entities[denseIndex] == entity,
                "Remove the existing component owner before inserting another generation at the same index."
            )
            dense[denseIndex] = component
            return
        }

        sparse[entity.index] = dense.count
        dense.append(component)
        entities.append(entity)
    }

    /// Removes the row owned by this complete identity, returning whether it existed.
    ///
    /// The last dense row fills the removed slot, so removal may change iteration
    /// order. Collect identities before structurally mutating a store during a
    /// system update; dense indices must not survive insertion or removal.
    @discardableResult
    mutating func remove(for entity: EntityID) -> Bool {
        guard let denseIndex = sparse[entity.index],
              entities[denseIndex] == entity else {
            return false
        }

        let lastIndex = dense.count - 1
        if denseIndex != lastIndex {
            dense[denseIndex] = dense[lastIndex]
            let movedEntity = entities[lastIndex]
            entities[denseIndex] = movedEntity
            sparse[movedEntity.index] = denseIndex
        }
        dense.removeLast()
        entities.removeLast()
        sparse.removeValue(forKey: entity.index)
        return true
    }

    /// Mutates an existing component row in place.
    ///
    /// This keeps hot systems from rebuilding and reinserting whole component
    /// values when they only need to adjust fields on an existing dense row.
    @discardableResult
    mutating func update(for entity: EntityID, _ body: (inout C) -> Void) -> Bool {
        guard let denseIndex = sparse[entity.index] else { return false }
        guard entities.indices.contains(denseIndex), entities[denseIndex] == entity else { return false }

        body(&dense[denseIndex])
        return true
    }

    /// Returns the component currently owned by this exact entity, if present.
    ///
    /// The lookup starts from the sparse index, then re-checks the full
    /// `EntityID` so a reused entity index does not read stale component data
    /// from an older generation.
    subscript(_ entity: EntityID) -> C? {
        get {
            guard let denseIndex = sparse[entity.index] else { return nil }
            guard entities[denseIndex] == entity else { return nil }
            return dense[denseIndex]
        }
    }
}
