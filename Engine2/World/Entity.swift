//
//  Entity.swift
//  Engine2
//
//  Created by Karl Groff on 3/8/26.
//

class Entity {
    let id: EntityID
    unowned let world: World

    init(in world: World) {
        self.id = world.reserveEntityID()
        self.world = world

        world.add(self)
    }
}
