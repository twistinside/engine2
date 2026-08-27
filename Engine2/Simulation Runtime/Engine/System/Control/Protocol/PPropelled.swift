/// Capability for entity facades with bounded thrust and fuel efficiency.
protocol PPropelled: Entity {
    var exhaustVelocity: Double { get }
    var maximumThrust: Double { get }
}

extension PPropelled {
    var exhaustVelocity: Double {
        guard let propulsion = world.propulsionComponents[id] else {
            fatalError("There is no propulsion component for the propelled entity with ID: \(id)")
        }
        return propulsion.exhaustVelocity
    }

    var maximumThrust: Double {
        guard let propulsion = world.propulsionComponents[id] else {
            fatalError("There is no propulsion component for the propelled entity with ID: \(id)")
        }
        return propulsion.maximumThrust
    }
}
