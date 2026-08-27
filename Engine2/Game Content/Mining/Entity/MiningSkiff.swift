import simd

/// Player-controlled dynamic craft for mining, hauling, and depot service.
final class MiningSkiff: Entity, PDisplayNamed, PMovable, PScalable, PRenderable, PSelectable,
    PGravityAffected, PLiveMass, PPropelled, PFueled, PCargoCarrying, PPlayerControlled,
    PCollidable, POrbitCircularizable {
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
        materialID: MaterialID
    ) {
        self.init(unregisteredID: world.reserveEntityID(), in: world)
        let initialState = Entity.InitialState(
            position: position,
            velocity: velocity,
            scale: SIMD3<Float>(repeating: Float(physicalRadius)),
            selectionState: .selected,
            cargo: CCargo(capacity: cargoCapacity),
            collisionBody: CCollisionBody(radius: physicalRadius, restitution: 0.35),
            displayName: CDisplayName(value: name),
            fuel: CFuel(capacity: fuelCapacity, remaining: fuelCapacity),
            gravityReceiver: CGravityReceiver(),
            mass: CMass(dryMass: dryMass),
            orbitPrimary: COrbitPrimary(primaryEntityID: primaryEntityID),
            playerControl: CPlayerControl(),
            previousPosition: CPreviousPosition(position: position),
            propulsion: CPropulsion(
                maximumThrust: maximumThrust,
                exhaustVelocity: exhaustVelocity
            ),
            renderable: RenderableInitialState(
                meshID: .ball,
                materialID: materialID
            ),
            selectionBounds: CSelectionBounds(radius: physicalRadius)
        )
        world.add(self, from: initialState)
    }
}
