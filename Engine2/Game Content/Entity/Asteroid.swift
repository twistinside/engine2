import simd

/// Finite-ore body that follows one deterministic circular rail.
final class Asteroid: Entity, DisplayNamed, Scalable, Renderable, Selectable,
    Orbiting, Mineable, Collidable, Destructible {
    convenience init(
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
        self.init(unregisteredID: world.reserveEntityID(), in: world)
        let initialState = Entity.InitialState(
            scale: SIMD3<Float>(repeating: Float(physicalRadius)),
            selectionState: .unselected,
            collisionBody: CollisionBodyInitialState(radius: physicalRadius, restitution: 0.35),
            displayName: name,
            interactionRange: interactionRange,
            miningRate: miningRate,
            orbitalRail: OrbitalRailInitialState(
                primaryEntityID: primaryEntityID,
                radius: orbitalRadius,
                angularSpeed: angularSpeed,
                phase: phase
            ),
            remainingOre: ore,
            renderable: RenderableInitialState(
                meshID: .ball,
                materialID: materialID
            ),
            selectionRadius: physicalRadius
        )
        world.add(self, from: initialState)
    }
}
