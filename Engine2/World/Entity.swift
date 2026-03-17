//
//  Entity.swift
//  Engine2
//
//  Created by Karl Groff on 3/8/26.
//

class Entity {
    let id: EntityID
    unowned let world: World

    /// Creates a live entity handle without registering it in the world.
    ///
    /// This keeps initialization side-effect free so test fixtures and future
    /// spawn flows can finish constructing the object before exposing `self`.
    init(id: EntityID, in world: World) {
        self.id = id
        self.world = world
    }

    /// Reserves an ID and registers the fully initialized entity with the world.
    convenience init(in world: World) {
        self.init(id: world.reserveEntityID(), in: world)
        world.add(self)
    }
}
