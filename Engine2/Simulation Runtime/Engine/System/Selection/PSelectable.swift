/// Capability for entity facades that expose live ECS-backed selection state.
///
/// This surface is intended for game code, UI, and inspection flows. The
/// default accessor resolves `CSelectable` from the entity's world and treats a
/// missing row as an invalid live-facade invariant.
protocol PSelectable: Entity {
    var selectionState: CSelectable.SelectionState { get }
}

extension PSelectable {
    var selectionState: CSelectable.SelectionState {
        guard let selectable = world.selectableComponents[self.id] else {
            fatalError("There is no selectable component for the selectable entity with ID: \(self.id)")
        }
        return selectable.selectionState
    }
}
