/// Read-only lifecycle visibility for a reference that supports deferred removal.
///
/// Conformance requires no Entity inheritance. The default implementation for Entity
/// projects its component state; systems request removal by updating that component directly.
protocol Destructible: AnyObject {
    /// Current registered state, or nil when no live lifecycle is available.
    var lifecycleState: DestructibleComponent.State? { get }
}

extension Destructible where Self: Entity {
    /// Current component state, or nil when this facade is not the registered instance.
    var lifecycleState: DestructibleComponent.State? {
        guard world.entity(for: id) === self else {
            return nil
        }
        return world.components[DestructibleComponent.self][id]?.state
    }
}
