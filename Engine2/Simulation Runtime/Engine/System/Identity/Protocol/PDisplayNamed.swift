/// Capability for entity facades with Game Content-authored display text.
protocol PDisplayNamed: Entity {
    var displayName: String { get }
}

extension PDisplayNamed {
    var displayName: String {
        guard let name = world.displayNameComponents[id] else {
            fatalError("There is no display name for the named entity with ID: \(id)")
        }
        return name.value
    }
}
