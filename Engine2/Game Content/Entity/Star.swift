import simd

/// Mining-slice star that supplies the sole dynamic gravity source.
final class Star: Entity, DisplayNamed, Scalable, Renderable, Selectable, GravitySource,
    LiveMass, Collidable {
    init(
        in world: World,
        name: String,
        gravitationalParameter: Double,
        mass: Double,
        radius: Double,
        materialID: MaterialID
    ) {
        let initialState = Entity.InitialState(
            position: .zero,
            scale: SIMD3<Float>(repeating: Float(radius)),
            selectionState: .unselected,
            collisionRadius: radius,
            collisionRestitution: 0.35,
            displayName: name,
            gravitationalParameter: gravitationalParameter,
            dryMass: mass,
            meshID: .ball,
            materialID: materialID,
            selectionRadius: radius
        )
        super.init(in: world, from: initialState)
    }
}
