import simd

/// A ballistic contact sensor that deals one point of damage and consumes itself on eligible solid-body impact.
/// Ownership exclusion, expiry, contact damage, and consumption are independently composed capabilities.
final class Missile: Entity, ContactDamaging, ContactConsumable, Ownable, Expirable, Movable, Scalable, Renderable {
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
            collisionResponse: .sensor,
            collisionOwnerPolicy: .exclude,
            collisionContactScope: .solidBodies,
            contactDamage: 1,
            ownerEntityID: ownerEntityID,
            lifetime: lifetime,
            meshID: .ball,
            materialID: .goldMetalSmooth
        )
        super.init(in: world, from: initialState)
    }
}
