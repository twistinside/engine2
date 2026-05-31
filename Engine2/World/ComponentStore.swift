//
//  ComponentStore.swift
//  Engine2
//
//  Created by Karl Groff on 3/8/26.
//

/// Sparse-set style storage for a single component type.
///
/// Component values live in `dense`, the owning `EntityID`s stay aligned in
/// `entities`, and `sparse` maps an entity index back to the dense slot when a
/// live row exists for that entity generation.
struct ComponentStore<C: Component> {
    var dense: [C] = []
    var entities: [EntityID] = []
    var sparse: [Int: Int] = [:]

    /// Inserts or replaces the component row for an entity.
    ///
    /// `sparse` is keyed by `entity.index`, but the dense slot is only valid if
    /// the stored `EntityID` still matches exactly. That extra generation check
    /// prevents a recycled index from aliasing a component that belonged to an
    /// older entity instance.
    mutating func insert(_ component: C, for entity: EntityID) {
        // Update in place when this exact entity already owns a dense slot.
        if let denseIndex = sparse[entity.index], entities.indices.contains(denseIndex), entities[denseIndex] == entity {
            dense[denseIndex] = component
            return
        }

        // Otherwise append a new dense row and point the sparse index at it.
        sparse[entity.index] = dense.count
        dense.append(component)
        entities.append(entity)
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
