import simd

/// Example Game Content entity that exposes typed capabilities over ECS state.
///
/// Constructing a ball registers the component rows implied by its capability
/// conformances. Its inherited identity and capability accessors remain live
/// facades over `World`; the object does not duplicate authoritative simulation
/// state. Its mesh and material identities are backend-neutral and owned by
/// Game Content.
class Ball: Entity, PMovable, PRotatable, PRenderable, PSelectable {
    let initialMeshID = MeshID.ball

    /// Material copied into authoritative ECS state when this ball registers.
    ///
    /// This remains only the spawn seed. The `materialID` capability accessor
    /// reads the current value from `World.renderableComponents` after spawn.
    let initialMaterialID: MaterialID

    /// Creates an unregistered ball with every capability seed initialized.
    ///
    /// A ball needs its material before registration because `World.add(_:from:)`
    /// reads the `PRenderable` capability while constructing `CRenderable`.
    init(
        unregisteredID id: EntityID,
        in world: World,
        materialID: MaterialID
    ) {
        self.initialMaterialID = materialID
        super.init(unregisteredID: id, in: world)
    }

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
        // Initialize the Ball-specific material seed before registration makes
        // the entity observable at the ECS boundary.
        self.init(
            unregisteredID: world.reserveEntityID(),
            in: world,
            materialID: materialID
        )
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
            )
        )
    }
}
