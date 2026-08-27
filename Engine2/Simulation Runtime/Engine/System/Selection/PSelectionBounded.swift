/// Capability for selectable entity facades with a live spherical hit bound.
protocol PSelectionBounded: PSelectable, PPositionable {
    var selectionRadius: Double { get }
}

extension PSelectionBounded {
    var selectionRadius: Double {
        guard let bounds = world.selectionBoundsComponents[id] else {
            fatalError("There are no selection bounds for the bounded entity with ID: \(id)")
        }
        return bounds.radius
    }
}
