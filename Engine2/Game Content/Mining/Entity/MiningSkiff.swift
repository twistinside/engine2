import simd

/// Player-controlled dynamic craft for mining, hauling, and depot service.
final class MiningSkiff: Entity, PDisplayNamed, PMovable, PScalable, PRenderable, PSelectable,
    PSelectionBounded, PGravityAffected, PLiveMass, PPropelled, PFueled, PCargoCarrying,
    PPlayerControlled, PCollidable {
    convenience init(
        in world: World,
        name: String,
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
        world.add(
            self,
            from: Entity.InitialState(
                position: position,
                velocity: velocity,
                scale: SIMD3<Float>(repeating: Float(physicalRadius)),
                selectionState: .selected
            ),
            renderable: RenderableInitialState(meshID: .ball, materialID: materialID)
        )
        world.displayNameComponents.insert(CDisplayName(value: name), for: id)
        world.selectionBoundsComponents.insert(CSelectionBounds(radius: physicalRadius), for: id)
        world.gravityReceiverComponents.insert(CGravityReceiver(), for: id)
        world.massComponents.insert(CMass(dryMass: dryMass), for: id)
        world.propulsionComponents.insert(
            CPropulsion(maximumThrust: maximumThrust, exhaustVelocity: exhaustVelocity),
            for: id
        )
        world.fuelComponents.insert(CFuel(capacity: fuelCapacity, remaining: fuelCapacity), for: id)
        world.cargoComponents.insert(CCargo(capacity: cargoCapacity), for: id)
        world.playerControlComponents.insert(CPlayerControl(), for: id)
        world.collisionBodyComponents.insert(
            CCollisionBody(radius: physicalRadius, restitution: 0.35),
            for: id
        )
        world.previousPositionComponents.insert(CPreviousPosition(position: position), for: id)
    }
}
