import simd

/// A visible ballistic projectile registered by missile launch systems through the normal entity boundary.
final class Missile: Entity, Fireable, Ownable, Expirable, Collidable, Destructible, Movable, Scalable, Renderable {
    init(
        in world: World,
        ownerEntityID: EntityID,
        position: SIMD3<Double>,
        velocity: SIMD3<Double>,
        radius: Double,
        lifetime: Double
    ) {
        precondition(position.isFinite && velocity.isFinite, "Missile position and velocity must be finite.")
        let renderRadius = Float(radius)
        precondition(
            renderRadius.isFinite && renderRadius > 0,
            "Missile radius must remain finite and positive for rendering."
        )
        let initialState = Entity.InitialState(
            position: position,
            velocity: velocity,
            scale: SIMD3<Float>(repeating: renderRadius),
            collisionRadius: radius,
            collisionRestitution: 0,
            ownerEntityID: ownerEntityID,
            lifetime: lifetime,
            meshID: .ball,
            materialID: .goldMetalSmooth
        )
        super.init(in: world, from: initialState)
    }
}
