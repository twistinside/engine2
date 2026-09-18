/// Capability for entity facades that contribute Newtonian gravity.
protocol GravitySource: Positionable {
    var gravitationalParameter: Double { get }
}

extension GravitySource {
    var gravitationalParameter: Double {
        guard let source = world.components[GravitySourceComponent.self][id] else {
            fatalError("There is no gravity source for the source entity with ID: \(id)")
        }
        return source.gravitationalParameter
    }
}
