/// World-space spherical bound used for deterministic pointer selection.
struct SelectionBoundsComponent: Component {
    let radius: Double

    init(radius: Double) {
        precondition(radius.isFinite && radius > 0, "A selection radius must be finite and positive.")
        self.radius = radius
    }
}

extension SelectionBoundsComponent {
    @MainActor init?(for entity: Entity, from state: Entity.InitialState) {
        precondition(
            (state.selectionRadius != nil) == (entity is Selectable),
            "InitialState.selectionRadius must be present exactly when the entity conforms to Selectable."
        )
        guard let selectionRadius = state.selectionRadius else { return nil }
        self.init(radius: selectionRadius)
    }
}
