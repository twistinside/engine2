/// Selection state for entities that can participate in UI, tooling, or
/// renderer selection feedback.
public struct CSelectable: PComponent {
    var selectionState: SelectionState = .unselected

    /// Finite interaction state shared by simulation selection and presentation.
    ///
    /// `highlighted` represents transient emphasis without changing the
    /// entity's committed selected or unselected status.
    public enum SelectionState: Codable, Equatable {
        case unselected
        case selected
        case highlighted
    }
}
