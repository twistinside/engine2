/// Capability for entity facades that contribute Newtonian gravity.
protocol PGravitySource: PPositionable {
    var gravitationalParameter: Double { get }
}

extension PGravitySource {
    var gravitationalParameter: Double {
        guard let source = world.gravitySourceComponents[id] else {
            fatalError("There is no gravity source for the source entity with ID: \(id)")
        }
        return source.gravitationalParameter
    }
}
