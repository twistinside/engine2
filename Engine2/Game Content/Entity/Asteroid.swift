import simd

/// Finite-ore body that follows one deterministic circular rail.
final class Asteroid: Entity, DisplayNamed, Scalable, Renderable, Selectable,
    Orbiting, Mineable, Collidable, Destructible {
    convenience init(
        in world: World,
        name: String,
        primaryEntityID: EntityID,
        primaryPosition: SIMD3<Double>,
        orbitalRadius: Double,
        angularSpeed: Double,
        phase: Double,
        physicalRadius: Double,
        ore: Double,
        interactionRange: Double,
        miningRate: Double,
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
            destructible: DestructibleComponent(),
            displayName: DisplayNameComponent(value: name),
            interaction: InteractionComponent(interactionRange: interactionRange),
            mineable: MineableComponent(miningRate: miningRate),
            orbitalRail: rail,
            oreDeposit: OreDepositComponent(remainingOre: ore),
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
