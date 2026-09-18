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

extension CollisionBodyComponent {
    @MainActor init?(for entity: Entity, from state: Entity.InitialState) {
        let isCollidable = entity is Collidable
        precondition(
            (state.collisionRadius != nil) == isCollidable &&
                (state.collisionResponse != nil) == isCollidable &&
                (state.collisionOwnerPolicy == nil || isCollidable) &&
                (state.collisionContactScope == nil || isCollidable),
            "Collidable requires radius and response; other entities must omit all collision policy."
        )
        guard let collisionRadius = state.collisionRadius,
              let collisionResponse = state.collisionResponse else {
            return nil
        }
        self.init(
            radius: collisionRadius,
            response: collisionResponse,
            ownerPolicy: state.collisionOwnerPolicy ?? .include,
            contactScope: state.collisionContactScope ?? .allBodies
        )
    }
}
