/// World-space spherical bound used for deterministic pointer selection.
struct CSelectionBounds: PComponent {
    let radius: Double

    init(radius: Double) {
        precondition(radius.isFinite && radius > 0, "A selection radius must be finite and positive.")
        self.radius = radius
    }
}
