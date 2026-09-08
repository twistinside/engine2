import simd

/// Rail-bound depot that unloads ore and supplies unlimited fuel.
final class MiningDepot: Entity, DisplayNamed, Scalable, Renderable, Selectable,
    Orbiting, Collidable, DepotServicing {
    convenience init(
        in world: World,
        name: String,
        primaryEntityID: EntityID,
        orbitalRadius: Double,
        angularSpeed: Double,
        phase: Double,
        physicalRadius: Double,
        interactionRange: Double,
        unloadingRate: Double,
        refuelingRate: Double,
        materialID: MaterialID
    ) {
        self.init(unregisteredID: world.reserveEntityID(), in: world)
        let initialState = Entity.InitialState(
            scale: SIMD3<Float>(repeating: Float(physicalRadius)),
            selectionState: .unselected,
            collisionBody: CollisionBodyInitialState(radius: physicalRadius, restitution: 0.35),
            depotService: DepotServiceInitialState(
                unloadingRate: unloadingRate,
                refuelingRate: refuelingRate
            ),
            displayName: name,
            interactionRange: interactionRange,
            orbitalRail: OrbitalRailInitialState(
                primaryEntityID: primaryEntityID,
                radius: orbitalRadius,
                angularSpeed: angularSpeed,
                phase: phase
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
