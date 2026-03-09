//
//  World.swift
//  Engine2
//
//  Created by Karl Groff on 3/8/26.
//

class World {
    var motionAccumulatorComponents = ComponentStore<CMotionAccumulator>()
    var positionComponents = ComponentStore<CPosition>()
    var velocityComponents = ComponentStore<CVelocity>()

    @discardableResult
    func add(_ entity: Entity) -> EntityID {
        return entity.id
    }

    func reserveEntityID() -> EntityID {
        return EntityID(index: 1, generation: 1)
    }

    func update(delta: Double) {
        // no op
    }
}
