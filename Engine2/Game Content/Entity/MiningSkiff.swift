import simd

/// Player-controlled dynamic craft for mining, missile fire, hauling, and depot service.
final class MiningSkiff: Entity, DisplayNamed, Scalable, Renderable, Selectable,
    CargoCarrying, PlayerControlled, OrbitCircularizable, MissileLaunching {
    init(
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
        missileSpeed: Double,
        missileLifetime: Double,
        missileRadius: Double,
        materialID: MaterialID
    ) {
        let initialState = Entity.InitialState(
            position: position,
            velocity: velocity,
            scale: SIMD3<Float>(repeating: Float(physicalRadius)),
            selectionState: .selected,
            cargoCapacity: cargoCapacity,
            cargoOre: 0,
            collisionRadius: physicalRadius,
            collisionRestitution: 0.35,
            displayName: name,
            fuelCapacity: fuelCapacity,
            fuelRemaining: fuelCapacity,
            dryMass: dryMass,
            missileSpeed: missileSpeed,
            missileLifetime: missileLifetime,
            missileRadius: missileRadius,
            orbitPrimaryID: primaryEntityID,
            maximumThrust: maximumThrust,
            exhaustVelocity: exhaustVelocity,
            meshID: .ball,
            materialID: materialID,
            selectionRadius: physicalRadius
        )
        super.init(in: world, from: initialState)
    }
}
