/// Designates the gravity source used for one entity's orbital maneuvers.
///
/// The complete generational identity preserves the same source selection for
/// live estimates and command execution. It does not constrain the entity to
/// an analytic rail.
struct OrbitPrimaryComponent: Component {
    let primaryEntityID: EntityID
}
