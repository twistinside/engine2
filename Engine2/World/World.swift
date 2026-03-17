//
//  World.swift
//  Engine2
//
//  Created by Karl Groff on 3/8/26.
//

class World {
    // MARK: Components
    var angularMotionAccumulatorComponents = ComponentStore<CAngularMotionAccumulator>()
    var angularVelocityComponents = ComponentStore<CAngularVelocity>()
    var motionAccumulatorComponents = ComponentStore<CMotionAccumulator>()
    var positionComponents = ComponentStore<CPosition>()
    var rotationComponents = ComponentStore<CRotation>()
    var scaleComponents = ComponentStore<CScale>()
    var velocityComponents = ComponentStore<CVelocity>()

    // MARK: Resources

    @discardableResult
    func add(_ entity: Entity) -> EntityID {
        return entity.id
    }

    func reserveEntityID() -> EntityID {
        return EntityID(index: 1, generation: 1)
    }
}
