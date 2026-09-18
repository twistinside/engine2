/// Owns every typed component store for one World.
///
/// The fixed metatype list drives allocation, capability-based registration,
/// and removal. All stores exist before any component initializer runs.
final class Components {
    /// Rails resolve before position, and position before collision history.
    /// Other initializers use authored seeds or already registered World state.
    static let types: [any Component.Type] = [
        OrbitalRailComponent.self,
        PositionComponent.self,
        MotionComponent.self,
        RotationComponent.self,
        AngularVelocityComponent.self,
        AngularMotionAccumulatorComponent.self,
        ScaleComponent.self,
        CargoComponent.self,
        CollisionBodyComponent.self,
        ContactDamageComponent.self,
        ContactConsumptionComponent.self,
        DepotServiceComponent.self,
        DisplayNameComponent.self,
        FuelComponent.self,
        GravityReceiverComponent.self,
        GravitySourceComponent.self,
        HealthComponent.self,
        InteractionComponent.self,
        MassComponent.self,
        MineableComponent.self,
        OwnershipComponent.self,
        LifetimeComponent.self,
        DestructibleComponent.self,
        MissileLauncherComponent.self,
        OrbitCircularizationAutopilotComponent.self,
        OrbitPrimaryComponent.self,
        OreDepositComponent.self,
        PlayerControlComponent.self,
        PreviousPositionComponent.self,
        PropulsionComponent.self,
        RenderableComponent.self,
        SelectableComponent.self,
        SelectionBoundsComponent.self
    ]

    private var stores: [ObjectIdentifier: any ComponentStoring] = [:]

    init() {
        for type in Self.types {
            register(type)
        }
    }

    /// Returns the World's live store for the requested component type.
    subscript<C: Component>(_ type: C.Type) -> ComponentStore<C> {
        guard let store = stores[ObjectIdentifier(type)] as? ComponentStore<C> else {
            preconditionFailure("Component type is not registered")
        }
        return store
    }

    /// Creates only rows supported by the entity's capabilities.
    func add(_ entity: Entity, from state: Entity.InitialState) {
        precondition(entity.world.components === self, "Component registration requires the entity's owning World.")
        for type in Self.types {
            add(type, for: entity, from: state)
        }
    }

    /// Removes this exact identity from every registered store.
    func remove(_ entity: EntityID) {
        for type in Self.types {
            guard let store = stores[ObjectIdentifier(type)] else {
                preconditionFailure("Component type is not registered")
            }
            store.remove(for: entity)
        }
    }

    private func register<C: Component>(_ type: C.Type) {
        let key = ObjectIdentifier(type)
        precondition(stores[key] == nil, "Component type is already registered")
        stores[key] = ComponentStore<C>()
    }

    private func add<C: Component>(_ type: C.Type, for entity: Entity, from state: Entity.InitialState) {
        guard let component = C(for: entity, from: state) else { return }
        self[type].insert(component, for: entity.id)
    }
}
