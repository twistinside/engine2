/// Capability for entity facades constrained to an analytic circular rail.
protocol Orbiting: Positionable {
    var orbitalRadius: Double { get }
    var orbitalVelocity: SIMD3<Double> { get }
}

extension Orbiting {
    var orbitalRadius: Double {
        guard let rail = world.orbitalRailComponents[id] else {
            fatalError("There is no orbital rail for the orbiting entity with ID: \(id)")
        }
        return rail.radius
    }

    var orbitalVelocity: SIMD3<Double> {
        guard let rail = world.orbitalRailComponents[id] else {
            fatalError("There is no orbital rail for the orbiting entity with ID: \(id)")
        }
        return rail.velocity
    }
}
