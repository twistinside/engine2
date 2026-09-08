import simd

/// Stable, typed game-object facade over component state owned by a `World`.
///
/// An entity retains its generational identity and an unowned reference to the
/// world that stores its authoritative data. Capability protocols add live,
/// ergonomic accessors for game code and tooling; simulation systems should
/// iterate component stores directly instead of using entity objects in hot
/// paths. After destruction, resolve the identity through `World.entity(for:)`
/// before using a facade: its capability accessors require live component rows.
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

        // Positionable
        var position: SIMD3<Double>? = nil

        // Movable
        var velocity: SIMD3<Double>? = nil
        var accelerationIntent: MotionComponent.AccelerationIntent? = nil
        var impulse: SIMD3<Double>? = nil

        // Orientable
        var rotation: simd_quatf? = nil

        // Rotatable
        var angularVelocity: SIMD3<Float>? = nil
        var angularAcceleration: SIMD3<Float>? = nil
        var angularImpulse: SIMD3<Float>? = nil

        // Scalable
        var scale: SIMD3<Float>? = nil

        // Selectable
        var selectionState: SelectableComponent.SelectionState? = nil

        // Specialized capabilities
        var cargo: CargoComponent? = nil
        var collisionBody: CollisionBodyComponent? = nil
        var depotService: DepotServiceComponent? = nil
        var destructible: DestructibleComponent? = nil
        var displayName: DisplayNameComponent? = nil
        var fuel: FuelComponent? = nil
        var gravityReceiver: GravityReceiverComponent? = nil
        var gravitySource: GravitySourceComponent? = nil
        var interaction: InteractionComponent? = nil
        var mass: MassComponent? = nil
        var mineable: MineableComponent? = nil
        var missile: MissileComponent? = nil
        var missileLauncher: MissileLauncherComponent? = nil
        var orbitPrimary: OrbitPrimaryComponent? = nil
        var orbitalRail: OrbitalRailComponent? = nil
        var oreDeposit: OreDepositComponent? = nil
        var playerControl: PlayerControlComponent? = nil
        var previousPosition: PreviousPositionComponent? = nil
        var propulsion: PropulsionComponent? = nil
        var renderable: RenderableInitialState? = nil
        var selectionBounds: SelectionBoundsComponent? = nil
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
