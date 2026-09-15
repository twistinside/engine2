import simd

/// Rail-bound depot that unloads ore and supplies unlimited fuel.
final class MiningDepot: Entity, DisplayNamed, Scalable, Renderable, Selectable,
    Orbiting, Collidable, DepotServicing {
    init(
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
        let initialState = Entity.InitialState(
            scale: SIMD3<Float>(repeating: Float(physicalRadius)),
            selectionState: .unselected,
            collisionRadius: physicalRadius,
            collisionResponse: .solid(restitution: 0.35),
            depotUnloadingRate: unloadingRate,
            depotRefuelingRate: refuelingRate,
            displayName: name,
            interactionRange: interactionRange,
            orbitalPrimaryID: primaryEntityID,
            orbitalRadius: orbitalRadius,
            orbitalAngularSpeed: angularSpeed,
            orbitalPhase: phase,
            meshID: .ball,
            materialID: materialID,
            selectionRadius: physicalRadius
        )
        super.init(in: world, from: initialState)
    }
}
