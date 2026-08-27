import simd

/// Rail-bound depot that unloads ore and supplies unlimited fuel.
final class MiningDepot: Entity, PDisplayNamed, PScalable, PRenderable, PSelectable,
    POrbiting, PCollidable, PDepotServicing {
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
        let initialState = Entity.InitialState(
            position: initialOrbitState.position,
            scale: SIMD3<Float>(repeating: Float(physicalRadius)),
            selectionState: .unselected,
            collisionBody: CCollisionBody(radius: physicalRadius, restitution: 0.35),
            depotService: CDepotService(
                unloadingRate: unloadingRate,
                refuelingRate: refuelingRate
            ),
            displayName: CDisplayName(value: name),
            interaction: CInteraction(interactionRange: interactionRange),
            orbitalRail: rail,
            previousPosition: CPreviousPosition(position: initialOrbitState.position),
            renderable: RenderableInitialState(
                meshID: .ball,
                materialID: materialID
            ),
            selectionBounds: CSelectionBounds(radius: physicalRadius)
        )
        world.add(self, from: initialState)
    }
}
