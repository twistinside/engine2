/// Open-ended display text for one entity.
///
/// Names are authored Game Content rather than a closed engine vocabulary, so
/// this component deliberately stores `String` instead of an enum.
struct DisplayNameComponent: Component {
    let value: String

    init(value: String) {
        precondition(!value.isEmpty, "An entity display name must not be empty.")
        self.value = value
    }
}
