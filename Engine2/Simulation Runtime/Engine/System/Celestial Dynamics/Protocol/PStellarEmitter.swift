/// Capability for stellar entity facades with live ECS-backed emission facts.
protocol PStellarEmitter: PCelestialBody {
    var luminosity: StellarLuminosity { get }
    var effectiveTemperature: ThermodynamicTemperature { get }
    var xuvLuminosityFraction: Double { get }
}

extension PStellarEmitter {
    var luminosity: StellarLuminosity {
        guard let emission = world.stellarEmissionComponents[id] else {
            fatalError("There is no stellar emission for the stellar entity with ID: \(id)")
        }
        return emission.luminosity
    }

    var effectiveTemperature: ThermodynamicTemperature {
        guard let emission = world.stellarEmissionComponents[id] else {
            fatalError("There is no stellar emission for the stellar entity with ID: \(id)")
        }
        return emission.effectiveTemperature
    }

    var xuvLuminosityFraction: Double {
        guard let emission = world.stellarEmissionComponents[id] else {
            fatalError("There is no stellar emission for the stellar entity with ID: \(id)")
        }
        return emission.xuvLuminosityFraction
    }
}
