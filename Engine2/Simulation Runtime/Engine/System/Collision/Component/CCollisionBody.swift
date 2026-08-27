/// Planar spherical collision shape and bounce response for one entity.
struct CCollisionBody: PComponent {
    let radius: Double
    let restitution: Double

    init(radius: Double, restitution: Double) {
        precondition(radius.isFinite && radius > 0, "A collision radius must be finite and positive.")
        precondition(
            restitution.isFinite && restitution >= 0 && restitution <= 1,
            "Collision restitution must be a finite value in 0...1."
        )
        self.radius = radius
        self.restitution = restitution
    }
}
