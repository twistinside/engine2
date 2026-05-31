//
//  Entity.swift
//  Engine2
//
//  Created by Karl Groff on 3/8/26.
//

import simd

class Entity {
    let id: EntityID
    unowned let world: World

    /// Optional spawn values used to seed authoritative world components.
    struct InitialState {
        static let empty = InitialState()

        // Positionable
        var position: SIMD3<Float>? = nil

        // Movable
        var velocity: SIMD3<Float>? = nil
        var accelerationIntent: CMotion.AccelerationIntent? = nil
        var impulse: SIMD3<Float>? = nil

        // Orientable
        var rotation: simd_quatf? = nil

        // Rotatable
        var angularVelocity: SIMD3<Float>? = nil
        var angularAcceleration: SIMD3<Float>? = nil
        var angularImpulse: SIMD3<Float>? = nil

        // Scalable
        var scale: SIMD3<Float>? = nil
    }

    /// Creates a live entity handle without registering it in the world.
    ///
    /// This entry point is for test fixtures and future reconstruction paths
    /// that need an entity wrapper before world registration occurs.
    init(unregisteredID id: EntityID, in world: World) {
        self.id = id
        self.world = world
    }

    /// Reserves an ID and registers the fully initialized entity with the world.
    convenience init(in world: World, from state: InitialState) {
        self.init(unregisteredID: world.reserveEntityID(), in: world)
        world.add(self, from: state)
    }
}
