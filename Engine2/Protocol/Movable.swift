//
//  Movable.swift
//  Engine2
//
//  Created by Karl Groff on 3/8/26.
//

protocol Movable: Entity, Positionable {
    var acceleration: SIMD3<Float> { get }
    var velocity: SIMD3<Float> { get }
}

extension Movable {
    var acceleration: SIMD3<Float> {
        guard let accelerationComponents = WPrimary.components[.acceleration] as? [CAcceleration] else {
            fatalError("Couldn't find accelerations for entities.")
        }
        guard id.index < accelerationComponents.count else {
            fatalError("Couldn't find acceleration for entity: \(self.id)")
        }
        return accelerationComponents[id.index].acceleration
    }

    var velocity: SIMD3<Float> {
        guard let velocityComponents = WPrimary.components[.velocity] as? [CVelocity] else {
            fatalError("Couldn't find positions for entities.")
        }
        guard id.index < velocityComponents.count else {
            fatalError("Couldn't find position for entity: \(self.id)")
        }
        return velocityComponents[id.index].velocity
    }
}
