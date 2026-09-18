import simd

/// Stable, typed game-object facade over component state owned by a `World`.
///
/// An entity retains its generational identity and an unowned reference to the
/// world that stores its authoritative component data, including lifecycle state.
/// Every subclass inherits Destructible. Capability protocols add live, ergonomic
/// accessors for game code and tooling; systems read and update component stores directly.
/// After destruction, resolve the identity through
/// `World.entity(for:)` before using a facade: its capability accessors require live rows.
class Entity: Destructible {
    let id: EntityID
    unowned let world: World

    /// Authored spawn facts that `World.add` turns into authoritative component rows.
    ///
    /// Scalar, SIMD, enum, and identity fields describe content directly, without
    /// intermediate seed structures, component instances, or live World lookups.
    /// Every specialized capability requires all of its authored fields.
    /// An orbital rail supplies the complete placement policy; omit explicit position
    /// and motion when providing a rail. World resolves its live primary and seeds
    /// position, rail velocity, and collision history before registration returns.
    /// Component initializers supply capability markers and transient controls.
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
        var cargoCapacity: Double? = nil
        var cargoOre: Double? = nil
        var collisionRadius: Double? = nil
        var collisionResponse: CollisionResponse? = nil
        var collisionOwnerPolicy: CollisionOwnerPolicy? = nil
        var collisionContactScope: CollisionContactScope? = nil
        var contactDamage: Double? = nil
        var health: Double? = nil
        var depotUnloadingRate: Double? = nil
        var depotRefuelingRate: Double? = nil
        var displayName: String? = nil
        var fuelCapacity: Double? = nil
        var fuelRemaining: Double? = nil
        var gravitationalParameter: Double? = nil
        var interactionRange: Double? = nil
        var dryMass: Double? = nil
        var miningRate: Double? = nil
        var ownerEntityID: EntityID? = nil
        var lifetime: Double? = nil
        var missileSpeed: Double? = nil
        var missileLifetime: Double? = nil
        var missileRadius: Double? = nil
        var orbitPrimaryID: EntityID? = nil
        var orbitalPrimaryID: EntityID? = nil
        var orbitalRadius: Double? = nil
        var orbitalAngularSpeed: Double? = nil
        var orbitalPhase: Double? = nil
        var remainingOre: Double? = nil
        var maximumThrust: Double? = nil
        var exhaustVelocity: Double? = nil
        var meshID: MeshID? = nil
        var materialID: MaterialID? = nil
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

    /// Reserves an ID and registers the entity's authored state with its World.
    ///
    /// Concrete entity initializers supply their spawn facts through `super.init`.
    /// World creates the component rows and derives runtime state before this returns.
    init(in world: World, from state: InitialState) {
        self.id = world.reserveEntityID()
        self.world = world
        world.add(self, from: state)
    }
}
