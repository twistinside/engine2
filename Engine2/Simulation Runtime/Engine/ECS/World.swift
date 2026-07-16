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
    var boundingSphereComponents = ComponentStore<CBoundingSphere>()
    var motionComponents = ComponentStore<CMotion>()
    var positionComponents = ComponentStore<CPosition>()
    var renderableComponents = ComponentStore<CRenderable>()
    var rotationComponents = ComponentStore<CRotation>()
    var scaleComponents = ComponentStore<CScale>()
    var selectableComponents = ComponentStore<CSelectable>()

    // MARK: Resources
    var camera = Camera()
    var input = InputState()

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
        // PPositionable
        precondition(state.position == nil || entity is PPositionable, "Initial state.position requires PPositionable conformance")
        if entity is PPositionable {
            positionComponents.insert(
                CPosition(position: state.position ?? .zero),
                for: entity.id
            )
        }

        // PSphereCollidable
        if let collidable = entity as? any PSphereCollidable {
            boundingSphereComponents.insert(
                CBoundingSphere(
                    radius: collidable.initialBoundingSphereRadius
                ),
                for: entity.id
            )
        }

        // PMovable
        precondition(
            (
                state.velocity == nil &&
                state.accelerationIntent == nil &&
                state.impulse == nil
            ) || entity is PMovable,
            "Initial movement state requires PMovable conformance"
        )
        if entity is PMovable {
            motionComponents.insert(
                CMotion(
                    velocity: state.velocity ?? .zero,
                    accelerationIntent: state.accelerationIntent ?? .idle,
                    impulse: state.impulse ?? .zero
                ),
                for: entity.id
            )
        }

        // POrientable
        precondition(state.rotation == nil || entity is POrientable, "Initial state.rotation requires POrientable conformance")
        if entity is POrientable {
            rotationComponents.insert(
                CRotation(rotation: state.rotation ?? Self.identityRotation),
                for: entity.id
            )
        }

        // PRotatable
        precondition(
            (state.angularVelocity == nil && state.angularAcceleration == nil && state.angularImpulse == nil) || entity is PRotatable,
            "Initial angular state requires PRotatable conformance"
        )
        if entity is PRotatable {
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

        // PScalable
        precondition(state.scale == nil || entity is PScalable, "Initial state.scale requires PScalable conformance")
        if entity is PScalable {
            scaleComponents.insert(
                CScale(scale: state.scale ?? SIMD3<Float>(repeating: 1)),
                for: entity.id
            )
        }

        // PRenderable
        if let renderable = entity as? any PRenderable {
            renderableComponents.insert(
                CRenderable(meshID: renderable.initialMeshID),
                for: entity.id
            )
        }

        // PSelectable
        precondition(state.selectionState == nil || entity is PSelectable, "Initial state.selectionState requires PSelectable conformance")
        if entity is PSelectable {
            selectableComponents.insert(
                CSelectable(selectionState: state.selectionState ?? .unselected),
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
