//
//  Rotatable.swift
//  Engine2
//
//  Created by Codex on 3/15/26.
//

protocol Rotatable: Orientable {
    var angularAcceleration: SIMD3<Float> { get }
    var angularImpulse: SIMD3<Float> { get }
    var angularVelocity: SIMD3<Float> { get }
}

extension Rotatable {
    var angularAcceleration: SIMD3<Float> {
        guard let accumulator = world.angularMotionAccumulatorComponents[self.id] else {
            fatalError("There is no angular motion accumulator for the rotating entity with ID: \(self.id)")
        }
        return accumulator.angularAcceleration
    }

    var angularImpulse: SIMD3<Float> {
        guard let accumulator = world.angularMotionAccumulatorComponents[self.id] else {
            fatalError("There is no angular motion accumulator for the rotating entity with ID: \(self.id)")
        }
        return accumulator.angularImpulse
    }

    var angularVelocity: SIMD3<Float> {
        guard let angularVelocity = world.angularVelocityComponents[self.id]?.angularVelocity else {
            fatalError("There is no angular velocity for the rotating entity with ID: \(self.id)")
        }
        return angularVelocity
    }
}
