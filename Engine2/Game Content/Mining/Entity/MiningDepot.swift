import simd

/// Rail-bound depot that unloads ore and supplies unlimited fuel.
final class MiningDepot: Entity, PDisplayNamed, PPositionable, PScalable, PRenderable, PSelectable,
    PSelectionBounded, POrbiting, PCollidable, PDepotServicing {
    convenience init(
        in world: World,
        name: String,
        primaryEntityID: EntityID,
        primaryPosition: SIMD3<Double>,
        orbitalRadius: Double,
        angularSpeed: Double,
        phase: Double,
        physicalRadius: Double,
        interactionRange: Double,
        unloadingRate: Double,
        refuelingRate: Double,
        materialID: MaterialID
    ) {
        var rail = COrbitalRail(
            primaryEntityID: primaryEntityID,
            radius: orbitalRadius,
            angularSpeed: angularSpeed,
            phase: phase
        )
        let initialOrbitState = rail.state(relativeTo: primaryPosition)
        rail.velocity = initialOrbitState.velocity

        self.init(unregisteredID: world.reserveEntityID(), in: world)
        world.add(
            self,
            from: Entity.InitialState(
                position: initialOrbitState.position,
                scale: SIMD3<Float>(repeating: Float(physicalRadius)),
                selectionState: .unselected
            ),
            renderable: RenderableInitialState(meshID: .ball, materialID: materialID)
        )
        world.displayNameComponents.insert(CDisplayName(value: name), for: id)
        world.selectionBoundsComponents.insert(CSelectionBounds(radius: physicalRadius), for: id)
        world.orbitalRailComponents.insert(rail, for: id)
        world.collisionBodyComponents.insert(
            CCollisionBody(radius: physicalRadius, restitution: 0.35),
            for: id
        )
        world.previousPositionComponents.insert(CPreviousPosition(position: initialOrbitState.position), for: id)
        world.depotServiceComponents.insert(
            CDepotService(
                interactionRange: interactionRange,
                unloadingRate: unloadingRate,
                refuelingRate: refuelingRate
            ),
            for: id
        )
    }
}
