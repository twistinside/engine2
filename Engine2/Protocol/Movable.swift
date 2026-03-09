//
//  Movable.swift
//  Engine2
//
//  Created by Karl Groff on 3/8/26.
//

protocol Movable: Entity, Positionable {
    var acceleration: SIMD3<Float> { get }
    var impulse: SIMD3<Float> { get }
    var velocity: SIMD3<Float> { get }
}

extension Movable {
    var acceleration: SIMD3<Float> {
        guard let accumulator = world.motionAccumulatorComponents[self.id] else {
            fatalError("There is no motion accumulator for the movable entity with ID: \(self.id)")
        }
        return accumulator.acceleration
    }

    var impulse: SIMD3<Float> {
        guard let accumulator = world.motionAccumulatorComponents[self.id] else {
            fatalError("There is no motion accumulator for the movable entity with ID: \(self.id)")
        }
        return accumulator.impulse
    }

    var velocity: SIMD3<Float> {
        guard let velocity = world.velocityComponents[self.id]?.velocity else {
            fatalError("There is no velocity for the movable entity with ID: \(self.id)")
        }
        return velocity
    }
}
