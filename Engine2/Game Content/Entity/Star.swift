import simd

/// Mining-slice star that supplies the sole dynamic gravity source.
final class Star: Entity, DisplayNamed, Scalable, Renderable, Selectable, GravitySource,
    LiveMass, Collidable {
    convenience init(
        in world: World,
        name: String,
        gravitationalParameter: Double,
        mass: Double,
        radius: Double,
        materialID: MaterialID
    ) {
        self.init(unregisteredID: world.reserveEntityID(), in: world)
        let initialState = Entity.InitialState(
            position: .zero,
            scale: SIMD3<Float>(repeating: Float(radius)),
            selectionState: .unselected,
            collisionBody: CollisionBodyComponent(radius: radius, restitution: 0.35),
            displayName: DisplayNameComponent(value: name),
            gravitySource: GravitySourceComponent(gravitationalParameter: gravitationalParameter),
            mass: MassComponent(dryMass: mass),
            previousPosition: PreviousPositionComponent(position: .zero),
            renderable: RenderableInitialState(
                meshID: .ball,
                materialID: materialID
            ),
            selectionBounds: SelectionBoundsComponent(radius: radius)
        )
        world.add(self, from: initialState)
    }
}
