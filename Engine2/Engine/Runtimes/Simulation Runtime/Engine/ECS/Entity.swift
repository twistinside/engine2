import simd

/// Stable, typed game-object facade over component state owned by a `World`.
///
/// An entity retains its generational identity and an unowned reference to the
/// world that stores its authoritative component data. The entity owns its lifecycle
/// state from registration through final removal and conforms to Destructible for every
/// subclass. Capability protocols add live, ergonomic accessors for game code and tooling.
/// Systems that process gameplay
/// components iterate stores directly; lifecycle systems may iterate the World's
/// registered entities. After destruction, resolve the identity through
/// `World.entity(for:)` before using a facade: its capability accessors require live rows.
class Entity {
    let id: EntityID
    unowned let world: World
    private(set) final var lifecycleState: EntityLifecycleState = .unregistered

    /// Authored spawn facts that `World.add` turns into authoritative component rows.
    ///
    /// Scalar, SIMD, enum, and identity fields describe content directly, without
    /// intermediate seed structures, component instances, or live World lookups.
    /// Every specialized capability requires all of its authored fields.
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

    /// Completes the World's first registration after its component rows and facade are installed.
    final func activateAfterRegistration() {
        precondition(
            lifecycleState == .unregistered && world.entity(for: id) === self,
            "Only a newly registered facade can become active."
        )
        lifecycleState = .active
    }

    /// Completes World destruction after the facade, component rows, and live references are removed.
    final func finishRemoval() {
        precondition(
            (lifecycleState == .active || lifecycleState == .pendingRemoval) && world.entity(for: id) == nil,
            "Only an unregistered former live facade can finish removal."
        )
        lifecycleState = .removed
    }
}

extension Entity: Destructible {
    /// Requests collection after all gameplay and effects systems finish.
    ///
    /// Every active entity can be removed, regardless of its other capabilities. Rows and live
    /// references remain intact while lifecycleState is pendingRemoval. Repeated requests
    /// are harmless. Unregistered, replaced, or removed facades return false.
    @discardableResult
    final func markForRemoval() -> Bool {
        guard world.entity(for: id) === self else {
            return false
        }
        switch lifecycleState {
        case .active:
            lifecycleState = .pendingRemoval
            return true
        case .pendingRemoval:
            return true
        case .unregistered, .removed:
            return false
        }
    }
}
