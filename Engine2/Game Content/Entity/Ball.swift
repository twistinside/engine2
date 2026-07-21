import simd

/// Example Game Content entity that exposes typed capabilities over ECS state.
///
/// Constructing a ball registers the component rows implied by its capability
/// conformances. Its inherited identity and capability accessors remain live
/// facades over `World`; the object does not duplicate authoritative simulation
/// state. Its mesh and material identities are backend-neutral and owned by
/// Game Content.
class Ball: Entity, PMovable, PRotatable, PRenderable, PSelectable {
    convenience init(
        in world: World,
        materialID: MaterialID = .warmDielectric,
        position: SIMD3<Float> = .zero,
        velocity: SIMD3<Float> = .zero,
        accelerationIntent: CMotion.AccelerationIntent = .idle,
        impulse: SIMD3<Float> = .zero,
        rotation: simd_quatf = simd_quatf(angle: 0, axis: SIMD3<Float>(0, 0, 1)),
        angularVelocity: SIMD3<Float> = .zero,
        angularAcceleration: SIMD3<Float> = .zero,
        angularImpulse: SIMD3<Float> = .zero,
        selectionState: CSelectable.SelectionState = .unselected
    ) {
        self.init(unregisteredID: world.reserveEntityID(), in: world)
        world.add(
            self,
            from: Entity.InitialState(
                position: position,
                velocity: velocity,
                accelerationIntent: accelerationIntent,
                impulse: impulse,
                rotation: rotation,
                angularVelocity: angularVelocity,
                angularAcceleration: angularAcceleration,
                angularImpulse: angularImpulse,
                selectionState: selectionState
            ),
            renderable: RenderableInitialState(
                meshID: .ball,
                materialID: materialID
            )
        )
    }
}
