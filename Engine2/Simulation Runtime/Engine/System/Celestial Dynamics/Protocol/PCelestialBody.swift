/// Capability for celestial entity facades backed by authoritative ECS rows.
///
/// These live reads support Game Content and tooling. Systems should iterate
/// the corresponding component stores directly in hot paths.
protocol PCelestialBody: Entity {
    var celestialBodyID: CelestialBodyID { get }
    var celestialBodyKind: CelestialBodyKind { get }
    var mass: AstronomicalMass { get }
    var physicalRadius: AstronomicalDistance { get }
    var orbitalState: PlanarStateVector { get }
    var orbitalAuthority: COrbitalMotion.Authority { get }
    var gravityParticipation: GravityParticipation { get }
}

extension PCelestialBody {
    var celestialBodyID: CelestialBodyID {
        guard let identity = world.celestialIdentityComponents[id] else {
            fatalError("There is no celestial identity for the celestial entity with ID: \(id)")
        }
        return identity.bodyID
    }

    var celestialBodyKind: CelestialBodyKind {
        guard let identity = world.celestialIdentityComponents[id] else {
            fatalError("There is no celestial identity for the celestial entity with ID: \(id)")
        }
        return identity.kind
    }

    var mass: AstronomicalMass {
        guard let massiveBody = world.massiveBodyComponents[id] else {
            fatalError("There is no massive-body component for the celestial entity with ID: \(id)")
        }
        return massiveBody.mass
    }

    var physicalRadius: AstronomicalDistance {
        guard let massiveBody = world.massiveBodyComponents[id] else {
            fatalError("There is no massive-body component for the celestial entity with ID: \(id)")
        }
        return massiveBody.physicalRadius
    }

    var orbitalState: PlanarStateVector {
        guard let orbitalMotion = world.orbitalMotionComponents[id] else {
            fatalError("There is no orbital motion for the celestial entity with ID: \(id)")
        }
        return orbitalMotion.orbitalState
    }

    var orbitalAuthority: COrbitalMotion.Authority {
        guard let orbitalMotion = world.orbitalMotionComponents[id] else {
            fatalError("There is no orbital motion for the celestial entity with ID: \(id)")
        }
        return orbitalMotion.authority
    }

    var gravityParticipation: GravityParticipation {
        guard let gravity = world.gravityParticipationComponents[id] else {
            fatalError("There is no gravity participation for the celestial entity with ID: \(id)")
        }
        return gravity.participation
    }
}
