import simd

/// Mining-slice star that supplies the sole dynamic gravity source.
final class Star: Entity, PDisplayNamed, PPositionable, PScalable, PRenderable, PSelectable, PSelectionBounded,
    PGravitySource, PLiveMass, PCollidable {
    convenience init(
        in world: World,
        name: String,
        gravitationalParameter: Double,
        mass: Double,
        radius: Double,
        materialID: MaterialID
    ) {
        self.init(unregisteredID: world.reserveEntityID(), in: world)
        world.add(
            self,
            from: Entity.InitialState(
                position: .zero,
                scale: SIMD3<Float>(repeating: Float(radius)),
                selectionState: .unselected
            ),
            renderable: RenderableInitialState(meshID: .ball, materialID: materialID)
        )
        world.displayNameComponents.insert(CDisplayName(value: name), for: id)
        world.selectionBoundsComponents.insert(CSelectionBounds(radius: radius), for: id)
        world.gravitySourceComponents.insert(
            CGravitySource(gravitationalParameter: gravitationalParameter),
            for: id
        )
        world.massComponents.insert(CMass(dryMass: mass), for: id)
        world.collisionBodyComponents.insert(CCollisionBody(radius: radius, restitution: 0.35), for: id)
        world.previousPositionComponents.insert(CPreviousPosition(position: .zero), for: id)
    }
}
