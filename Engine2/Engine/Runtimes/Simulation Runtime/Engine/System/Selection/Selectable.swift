/// Capability for positioned entity facades with live selection state and a spherical hit bound.
///
/// This surface is intended for game code, UI, and inspection flows. The
/// default accessors resolve the selection rows from the entity's world and
/// treat missing state as an invalid live-facade invariant.
protocol Selectable: Positionable {
    var selectionRadius: Double { get }
    var selectionState: SelectableComponent.SelectionState { get }
}

extension Selectable {
    var selectionRadius: Double {
        guard let bounds = world.components[SelectionBoundsComponent.self][id] else {
            fatalError("There are no selection bounds for the selectable entity with ID: \(id)")
        }
        return bounds.radius
    }

    var selectionState: SelectableComponent.SelectionState {
        guard let selectable = world.components[SelectableComponent.self][self.id] else {
            fatalError("There is no selectable component for the selectable entity with ID: \(self.id)")
        }
        return selectable.selectionState
    }
}
