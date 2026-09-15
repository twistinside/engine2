/// Capability for positioned entity facades with a planar collision sphere.
protocol Collidable: Positionable {
    var collisionRadius: Double { get }
    var collisionResponse: CollisionResponse { get }
    var collisionOwnerPolicy: CollisionOwnerPolicy { get }
    var collisionContactScope: CollisionContactScope { get }
}

extension Collidable {
    var collisionRadius: Double {
        guard let body = world.collisionBodyComponents[id] else {
            fatalError("There is no collision body for the collidable entity with ID: \(id)")
        }
        return body.radius
    }

    var collisionResponse: CollisionResponse {
        guard let body = world.collisionBodyComponents[id] else {
            fatalError("There is no collision body for the collidable entity with ID: \(id)")
        }
        return body.response
    }

    var collisionOwnerPolicy: CollisionOwnerPolicy {
        guard let body = world.collisionBodyComponents[id] else {
            fatalError("There is no collision body for the collidable entity with ID: \(id)")
        }
        return body.ownerPolicy
    }

    var collisionContactScope: CollisionContactScope {
        guard let body = world.collisionBodyComponents[id] else {
            fatalError("There is no collision body for the collidable entity with ID: \(id)")
        }
        return body.contactScope
    }
}
