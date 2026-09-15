/// Validated planar collision shape, physical response, and owner-contact policy.
struct CollisionBodyComponent: Component {
    let radius: Double
    let response: CollisionResponse
    let ownerPolicy: CollisionOwnerPolicy
    let contactScope: CollisionContactScope

    init(
        radius: Double,
        response: CollisionResponse,
        ownerPolicy: CollisionOwnerPolicy = .include,
        contactScope: CollisionContactScope = .allBodies
    ) {
        precondition(radius.isFinite && radius > 0, "A collision radius must be finite and positive.")
        if case let .solid(restitution) = response {
            precondition(
                restitution.isFinite && restitution >= 0 && restitution <= 1,
                "Collision restitution must be a finite value in 0...1."
            )
        }
        self.radius = radius
        self.response = response
        self.ownerPolicy = ownerPolicy
        self.contactScope = contactScope
    }
}
