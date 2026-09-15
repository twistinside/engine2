/// Registration and removal state owned by one Entity facade for its entire lifetime.
///
/// Gameplay component data remains in World stores. Removal requests change this state
/// until the Engine's final collection removes the registered facade and its rows.
enum EntityLifecycleState: Equatable, Sendable {
    case unregistered
    case active
    case pendingRemoval
    case removed
}
