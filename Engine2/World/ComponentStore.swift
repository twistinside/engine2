//
//  ComponentStore.swift
//  Engine2
//
//  Created by Karl Groff on 3/8/26.
//

struct ComponentStore<C: Component> {
    var dense: [C] = []
    var entities: [EntityID] = []
    var sparse: [Int: Int] = [:]

    mutating func insert(_ component: C, for entity: EntityID) {
        if let denseIndex = sparse[entity.index], entities.indices.contains(denseIndex), entities[denseIndex] == entity {
            dense[denseIndex] = component
            return
        }

        sparse[entity.index] = dense.count
        dense.append(component)
        entities.append(entity)
    }

    subscript(_ entity: EntityID) -> C? {
        get {
            guard let denseIndex = sparse[entity.index] else { return nil }
            guard entities[denseIndex] == entity else { return nil }
            return dense[denseIndex]
        }
    }
}
