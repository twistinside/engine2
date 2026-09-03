/// Capability for positioned entity facades with a planar collision sphere.
protocol Collidable: Positionable {
    var collisionRadius: Double { get }
    var restitution: Double { get }
}

extension Collidable {
    var collisionRadius: Double {
        guard let body = world.collisionBodyComponents[id] else {
            fatalError("There is no collision body for the collidable entity with ID: \(id)")
        }
        return body.radius
    }

    var restitution: Double {
        guard let body = world.collisionBodyComponents[id] else {
            fatalError("There is no collision body for the collidable entity with ID: \(id)")
        }
        return body.restitution
    }
}
