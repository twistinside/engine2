/// Capability for positioned entity facades with a planar collision sphere.
protocol PCollidable: PPositionable {
    var collisionRadius: Double { get }
    var restitution: Double { get }
}

extension PCollidable {
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
