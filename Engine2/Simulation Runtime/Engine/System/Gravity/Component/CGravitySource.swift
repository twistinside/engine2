/// Positive Newtonian gravitational parameter supplied by one source entity.
///
/// The value uses cubic meters per second squared. Carrying `mu` directly lets
/// fictional Game Content choose compact orbital scales without inventing a
/// second authoritative mass solely for gravity.
struct CGravitySource: PComponent {
    let gravitationalParameter: Double

    init(gravitationalParameter: Double) {
        precondition(
            gravitationalParameter.isFinite && gravitationalParameter > 0,
            "A gravitational parameter must be finite and positive."
        )
        self.gravitationalParameter = gravitationalParameter
    }
}
