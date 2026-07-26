import simd

/// Example Game Content entity that exposes typed capabilities over ECS state.
///
/// Constructing a ball registers the component rows implied by its capability
/// conformances. Its inherited identity and capability accessors remain live
/// facades over `World`; the object does not duplicate authoritative simulation
/// state. Its mesh and material identities are backend-neutral and owned by
/// Game Content.
class Ball: Entity, PMovable, PRotatable, PRenderable, PSelectable {
    /// Creates a Ball with an explicitly authored material identity.
    ///
    /// Position, motion, orientation, and selection defaults are neutral per-instance
    /// seed values. Omitting them cannot establish shared Simulation policy, while the
    /// required material identity prevents an authored presentation choice from being hidden.
    convenience init(
        in world: World,
        materialID: MaterialID,
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
        let initialState = Entity.InitialState(
            position: position,
            velocity: velocity,
            accelerationIntent: accelerationIntent,
            impulse: impulse,
            rotation: rotation,
            angularVelocity: angularVelocity,
            angularAcceleration: angularAcceleration,
            angularImpulse: angularImpulse,
            selectionState: selectionState
        )
        let renderableState = RenderableInitialState(
            meshID: .ball,
            materialID: materialID
        )
        world.add(self, from: initialState, renderable: renderableState)
    }
}
