/// Selects how one body reaches the end of a numerical orbital step.
nonisolated enum PlanarOrbitalPropagation: Equatable, Sendable {
    /// Gravity and the starting state determine the complete ending state.
    case integrated

    /// The caller supplies an exact ending state, such as a rail evaluation.
    ///
    /// A prescribed body may emit gravity at both endpoints. The stepper does
    /// not apply accumulated acceleration to its supplied state.
    case prescribed(endState: PlanarStateVector)

    var isIntegrated: Bool {
        if case .integrated = self {
            return true
        }
        return false
    }
}
