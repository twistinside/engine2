//
//  World.swift
//  Engine2
//
//  Created by Karl Groff on 3/8/26.
//

import simd

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
    private static let identityRotation = simd_quatf(angle: 0, axis: SIMD3<Float>(0, 0, 1))
    private var nextEntityIndex = 0

    /// Creates the component rows implied by the entity's advertised capabilities.
    ///
    /// Capability protocols decide which component stores receive rows; the
    /// optional initial state only supplies the seed values for those rows.
    ///
    /// Seed the baseline transform rows first so higher-level capabilities
    /// such as motion and rotation always have their backing state.
    ///
    /// Reject seed values for capabilities this entity does not expose. That
    /// keeps object APIs and ECS rows aligned instead of silently discarding
    /// caller intent.
    @discardableResult
    func add(_ entity: Entity, from state: Entity.InitialState = .empty) -> EntityID {
        // Positionable
        precondition(state.position == nil || entity is Positionable, "Initial state.position requires Positionable conformance")
        if entity is Positionable {
            positionComponents.insert(
                CPosition(position: state.position ?? .zero),
                for: entity.id
            )
        }

        // Movable
        precondition(
            (state.velocity == nil && state.acceleration == nil && state.impulse == nil) || entity is Movable,
            "Initial movement state requires Movable conformance"
        )
        if entity is Movable {
            velocityComponents.insert(
                CVelocity(velocity: state.velocity ?? .zero),
                for: entity.id
            )
            motionAccumulatorComponents.insert(
                CMotionAccumulator(
                    acceleration: state.acceleration ?? .zero,
                    impulse: state.impulse ?? .zero
                ),
                for: entity.id
            )
        }

        // Orientable
        precondition(state.rotation == nil || entity is Orientable, "Initial state.rotation requires Orientable conformance")
        if entity is Orientable {
            rotationComponents.insert(
                CRotation(rotation: state.rotation ?? Self.identityRotation),
                for: entity.id
            )
        }

        // Rotatable
        precondition(
            (state.angularVelocity == nil && state.angularAcceleration == nil && state.angularImpulse == nil) || entity is Rotatable,
            "Initial angular state requires Rotatable conformance"
        )
        if entity is Rotatable {
            angularVelocityComponents.insert(
                CAngularVelocity(angularVelocity: state.angularVelocity ?? .zero),
                for: entity.id
            )
            angularMotionAccumulatorComponents.insert(
                CAngularMotionAccumulator(
                    angularAcceleration: state.angularAcceleration ?? .zero,
                    angularImpulse: state.angularImpulse ?? .zero
                ),
                for: entity.id
            )
        }

        // Scalable
        precondition(state.scale == nil || entity is Scalable, "Initial state.scale requires Scalable conformance")
        if entity is Scalable {
            scaleComponents.insert(
                CScale(scale: state.scale ?? SIMD3<Float>(repeating: 1)),
                for: entity.id
            )
        }

        return entity.id
    }

    func reserveEntityID() -> EntityID {
        // Until entity destruction exists, each reservation consumes a fresh
        // index so entity identities never alias a previous live row.
        let entityID = EntityID(index: nextEntityIndex, generation: 0)
        nextEntityIndex += 1
        return entityID
    }
}
