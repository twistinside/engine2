import simd

/// Stable, typed game-object facade over component state owned by a `World`.
///
/// An entity retains its generational identity and an unowned reference to the
/// world that stores its authoritative data. Capability protocols add live,
/// ergonomic accessors for game code and tooling; simulation systems should
/// iterate component stores directly instead of using entity objects in hot
/// paths.
class Entity {
    let id: EntityID
    unowned let world: World

    /// Complete typed values used to seed authoritative component rows.
    ///
    /// Foundational transform and motion values remain decomposed where neutral
    /// defaults are useful. Specialized capabilities carry complete component
    /// values so `World` can validate and perform every construction-time write.
    struct InitialState {
        static let empty = InitialState()

        // PPositionable
        var position: SIMD3<Double>? = nil

        // PMovable
        var velocity: SIMD3<Double>? = nil
        var accelerationIntent: CMotion.AccelerationIntent? = nil
        var impulse: SIMD3<Double>? = nil

        // POrientable
        var rotation: simd_quatf? = nil

        // PRotatable
        var angularVelocity: SIMD3<Float>? = nil
        var angularAcceleration: SIMD3<Float>? = nil
        var angularImpulse: SIMD3<Float>? = nil

        // PScalable
        var scale: SIMD3<Float>? = nil

        // PSelectable
        var selectionState: CSelectable.SelectionState? = nil

        // Specialized capabilities
        var cargo: CCargo? = nil
        var collisionBody: CCollisionBody? = nil
        var depotService: CDepotService? = nil
        var displayName: CDisplayName? = nil
        var fuel: CFuel? = nil
        var gravityReceiver: CGravityReceiver? = nil
        var gravitySource: CGravitySource? = nil
        var interaction: CInteraction? = nil
        var mass: CMass? = nil
        var mineable: CMineable? = nil
        var orbitPrimary: COrbitPrimary? = nil
        var orbitalRail: COrbitalRail? = nil
        var oreDeposit: COreDeposit? = nil
        var playerControl: CPlayerControl? = nil
        var previousPosition: CPreviousPosition? = nil
        var propulsion: CPropulsion? = nil
        var renderable: RenderableInitialState? = nil
        var selectionBounds: CSelectionBounds? = nil
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
