import simd

/// A visible ballistic projectile registered by missile launch systems through the normal entity boundary.
final class Missile: Entity, MissileProjectile, Scalable, Renderable {
    convenience init(
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
        self.init(unregisteredID: world.reserveEntityID(), in: world)
        world.add(
            self,
            from: Entity.InitialState(
                position: position,
                velocity: velocity,
                scale: SIMD3<Float>(repeating: renderRadius),
                collisionBody: CollisionBodyInitialState(radius: radius, restitution: 0),
                missile: MissileInitialState(ownerEntityID: ownerEntityID, lifetime: lifetime),
                renderable: RenderableInitialState(meshID: .ball, materialID: .goldMetalSmooth)
            )
        )
    }
}
