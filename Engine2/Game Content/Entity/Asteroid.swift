import simd

/// Finite-ore body that follows one deterministic circular rail.
final class Asteroid: Entity, DisplayNamed, Scalable, Renderable, Selectable,
    Orbiting, Mineable, Collidable {
    init(
        in world: World,
        name: String,
        primaryEntityID: EntityID,
        orbitalRadius: Double,
        angularSpeed: Double,
        phase: Double,
        physicalRadius: Double,
        ore: Double,
        interactionRange: Double,
        miningRate: Double,
        materialID: MaterialID
    ) {
        let initialState = Entity.InitialState(
            scale: SIMD3<Float>(repeating: Float(physicalRadius)),
            selectionState: .unselected,
            collisionRadius: physicalRadius,
            collisionRestitution: 0.35,
            displayName: name,
            interactionRange: interactionRange,
            miningRate: miningRate,
            orbitalPrimaryID: primaryEntityID,
            orbitalRadius: orbitalRadius,
            orbitalAngularSpeed: angularSpeed,
            orbitalPhase: phase,
            remainingOre: ore,
            meshID: .ball,
            materialID: materialID,
            selectionRadius: physicalRadius
        )
        super.init(in: world, from: initialState)
    }
}
