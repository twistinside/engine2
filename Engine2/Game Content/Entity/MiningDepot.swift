import simd

/// Rail-bound depot that unloads ore and supplies unlimited fuel.
final class MiningDepot: Entity, DisplayNamed, Scalable, Renderable, Selectable,
    Orbiting, Collidable, DepotServicing {
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
        var rail = OrbitalRailComponent(
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
            collisionBody: CollisionBodyComponent(radius: physicalRadius, restitution: 0.35),
            depotService: DepotServiceComponent(
                unloadingRate: unloadingRate,
                refuelingRate: refuelingRate
            ),
            displayName: DisplayNameComponent(value: name),
            interaction: InteractionComponent(interactionRange: interactionRange),
            orbitalRail: rail,
            previousPosition: PreviousPositionComponent(position: initialOrbitState.position),
            renderable: RenderableInitialState(
                meshID: .ball,
                materialID: materialID
            ),
            selectionBounds: SelectionBoundsComponent(radius: physicalRadius)
        )
        world.add(self, from: initialState)
    }
}
