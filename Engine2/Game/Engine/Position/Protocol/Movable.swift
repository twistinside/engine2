//
//  Movable.swift
//  Engine2
//
//  Created by Karl Groff on 3/8/26.
//

protocol Movable: Positionable {
    var acceleration: SIMD3<Float> { get }
    var accelerationIntent: CMotion.AccelerationIntent { get }
    var impulse: SIMD3<Float> { get }
    var velocity: SIMD3<Float> { get }
}

extension Movable {
    var acceleration: SIMD3<Float> {
        guard let motion = world.motionComponents[self.id] else {
            fatalError("There is no motion component for the movable entity with ID: \(self.id)")
        }
        return motion.acceleration
    }

    var accelerationIntent: CMotion.AccelerationIntent {
        guard let motion = world.motionComponents[self.id] else {
            fatalError("There is no motion component for the movable entity with ID: \(self.id)")
        }
        return motion.accelerationIntent
    }

    var impulse: SIMD3<Float> {
        guard let motion = world.motionComponents[self.id] else {
            fatalError("There is no motion component for the movable entity with ID: \(self.id)")
        }
        return motion.impulse
    }

    var velocity: SIMD3<Float> {
        guard let motion = world.motionComponents[self.id] else {
            fatalError("There is no motion component for the movable entity with ID: \(self.id)")
        }
        return motion.velocity
    }
}
