/// Selection state for entities that can participate in UI, tooling, or
/// renderer selection feedback.
struct SelectableComponent: Component {
    var selectionState: SelectionState = .unselected

    /// Finite interaction state shared by simulation selection and presentation.
    ///
    /// `highlighted` represents transient emphasis without changing the
    /// entity's committed selected or unselected status.
    enum SelectionState: Codable, Equatable {
        case unselected
        case selected
        case highlighted
    }
}

extension SelectableComponent {
    @MainActor init?(for entity: Entity, from state: Entity.InitialState) {
        let isSelectable = entity is Selectable
        precondition(
            state.selectionState == nil || isSelectable,
            "Initial state.selectionState requires Selectable conformance"
        )
        precondition(
            (state.selectionRadius != nil) == isSelectable,
            "InitialState.selectionRadius must be present exactly when the entity conforms to Selectable."
        )
        guard isSelectable else {
            return nil
        }

        let selectionState: SelectableComponent.SelectionState = entity.world.selectedEntityID == entity.id
            ? .selected
            : state.selectionState ?? .unselected
        self.init(selectionState: selectionState)
    }
}
