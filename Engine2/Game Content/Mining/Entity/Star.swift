import simd

/// Mining-slice star that supplies the sole dynamic gravity source.
final class Star: Entity, PDisplayNamed, PScalable, PRenderable, PSelectable, PGravitySource,
    PLiveMass, PCollidable {
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
            collisionBody: CCollisionBody(radius: radius, restitution: 0.35),
            displayName: CDisplayName(value: name),
            gravitySource: CGravitySource(gravitationalParameter: gravitationalParameter),
            mass: CMass(dryMass: mass),
            previousPosition: CPreviousPosition(position: .zero),
            renderable: RenderableInitialState(
                meshID: .ball,
                materialID: materialID
            ),
            selectionBounds: CSelectionBounds(radius: radius)
        )
        world.add(self, from: initialState)
    }
}
