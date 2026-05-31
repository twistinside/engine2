//
//  Ball.swift
//  Engine2
//
//  Created by Karl Groff on 3/8/26.
//

import simd

class Ball: Entity, Movable, Rotatable {
    convenience init(
        in world: World,
        position: SIMD3<Float> = .zero,
        velocity: SIMD3<Float> = .zero,
        accelerationIntent: CMotion.AccelerationIntent = .idle,
        impulse: SIMD3<Float> = .zero,
        rotation: simd_quatf = simd_quatf(angle: 0, axis: SIMD3<Float>(0, 0, 1)),
        angularVelocity: SIMD3<Float> = .zero,
        angularAcceleration: SIMD3<Float> = .zero,
        angularImpulse: SIMD3<Float> = .zero
    ) {
        self.init(
            in: world,
            from: Entity.InitialState(
                position: position,
                velocity: velocity,
                accelerationIntent: accelerationIntent,
                impulse: impulse,
                rotation: rotation,
                angularVelocity: angularVelocity,
                angularAcceleration: angularAcceleration,
                angularImpulse: angularImpulse
            )
        )
    }
}
