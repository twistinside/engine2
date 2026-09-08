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

    /// Authored spawn facts that `World.add` turns into authoritative component rows.
    ///
    /// Values describe content without containing components or resolving World state.
    /// An orbital rail supplies the complete placement policy; omit explicit position
    /// and motion when providing a rail. World resolves its live primary and seeds
    /// position, rail velocity, and collision history before registration returns.
    /// Capability markers and transient controls are initialized by World.
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
        var cargo: CargoInitialState? = nil
        var collisionBody: CollisionBodyInitialState? = nil
        var depotService: DepotServiceInitialState? = nil
        var displayName: String? = nil
        var fuel: FuelInitialState? = nil
        var gravitationalParameter: Double? = nil
        var interactionRange: Double? = nil
        var dryMass: Double? = nil
        var miningRate: Double? = nil
        var missile: MissileInitialState? = nil
        var missileLauncher: MissileLauncherInitialState? = nil
        var orbitPrimaryID: EntityID? = nil
        var orbitalRail: OrbitalRailInitialState? = nil
        var remainingOre: Double? = nil
        var propulsion: PropulsionInitialState? = nil
        var renderable: RenderableInitialState? = nil
        var selectionRadius: Double? = nil
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
