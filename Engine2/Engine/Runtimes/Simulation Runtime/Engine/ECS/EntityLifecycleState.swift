/// Lifecycle state stored while an entity remains registered in its World.
///
/// Systems mark pending removal before final collection. An absent lifecycle component
/// represents an unregistered or removed identity; neither state needs a retained row.
nonisolated enum EntityLifecycleState: Codable, Equatable, Sendable {
    case active
    case pendingRemoval
}
