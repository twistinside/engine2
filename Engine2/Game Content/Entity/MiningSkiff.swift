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
        missileLauncher: MissileLauncherComponent,
        materialID: MaterialID
    ) {
        self.init(unregisteredID: world.reserveEntityID(), in: world)
        let initialState = Entity.InitialState(
            position: position,
            velocity: velocity,
            scale: SIMD3<Float>(repeating: Float(physicalRadius)),
            selectionState: .selected,
            cargo: CargoComponent(capacity: cargoCapacity),
            collisionBody: CollisionBodyComponent(radius: physicalRadius, restitution: 0.35),
            displayName: DisplayNameComponent(value: name),
            fuel: FuelComponent(capacity: fuelCapacity, remaining: fuelCapacity),
            gravityReceiver: GravityReceiverComponent(),
            mass: MassComponent(dryMass: dryMass),
            missileLauncher: missileLauncher,
            orbitPrimary: OrbitPrimaryComponent(primaryEntityID: primaryEntityID),
            playerControl: PlayerControlComponent(isFireRequested: false),
            previousPosition: PreviousPositionComponent(position: position),
            propulsion: PropulsionComponent(
                maximumThrust: maximumThrust,
                exhaustVelocity: exhaustVelocity
            ),
            renderable: RenderableInitialState(
                meshID: .ball,
                materialID: materialID
            ),
            selectionBounds: SelectionBoundsComponent(radius: physicalRadius)
        )
        world.add(self, from: initialState)
    }
}
