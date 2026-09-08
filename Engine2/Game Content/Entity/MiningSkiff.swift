import simd

/// Player-controlled dynamic craft for mining, missile fire, hauling, and depot service.
final class MiningSkiff: Entity, DisplayNamed, Scalable, Renderable, Selectable,
    CargoCarrying, PlayerControlled, OrbitCircularizable, MissileLaunching {
    convenience init(
        in world: World,
        name: String,
        primaryEntityID: EntityID,
        position: SIMD3<Double>,
        velocity: SIMD3<Double>,
        physicalRadius: Double,
        dryMass: Double,
        fuelCapacity: Double,
        cargoCapacity: Double,
        maximumThrust: Double,
        exhaustVelocity: Double,
        missileLauncher: MissileLauncherInitialState,
        materialID: MaterialID
    ) {
        self.init(unregisteredID: world.reserveEntityID(), in: world)
        let initialState = Entity.InitialState(
            position: position,
            velocity: velocity,
            scale: SIMD3<Float>(repeating: Float(physicalRadius)),
            selectionState: .selected,
            cargo: CargoInitialState(capacity: cargoCapacity, ore: 0),
            collisionBody: CollisionBodyInitialState(radius: physicalRadius, restitution: 0.35),
            displayName: name,
            fuel: FuelInitialState(capacity: fuelCapacity, remaining: fuelCapacity),
            dryMass: dryMass,
            missileLauncher: missileLauncher,
            orbitPrimaryID: primaryEntityID,
            propulsion: PropulsionInitialState(
                maximumThrust: maximumThrust,
                exhaustVelocity: exhaustVelocity
            ),
            renderable: RenderableInitialState(
                meshID: .ball,
                materialID: materialID
            ),
            selectionRadius: physicalRadius
        )
        world.add(self, from: initialState)
    }
}
