/// Authoritative lifecycle state for every registered entity.
///
/// World creates an active row on first registration. Systems set pendingRemoval to
/// request final collection without removing rows that later systems may still inspect.
/// Reseeding preserves this state; EntityRemovalSystem collects pending identities.
struct EntityLifecycleComponent: Component {
    var state: EntityLifecycleState = .active
}
