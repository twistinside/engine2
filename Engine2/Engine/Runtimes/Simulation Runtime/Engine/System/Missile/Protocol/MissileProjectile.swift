/// Capability for a moving projectile whose impacts and expiry belong to the Simulation.
protocol MissileProjectile: Collidable, Movable {
    var ownerEntityID: EntityID { get }
    var remainingLifetime: Double { get }
}

extension MissileProjectile {
    var ownerEntityID: EntityID {
        guard let missile = world.missileComponents[id] else {
            fatalError("There is no missile component for the projectile with ID: \(id)")
        }
        return missile.ownerEntityID
    }

    var remainingLifetime: Double {
        guard let missile = world.missileComponents[id] else {
            fatalError("There is no missile component for the projectile with ID: \(id)")
        }
        return missile.remainingLifetime
    }
}
