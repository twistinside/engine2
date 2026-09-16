/// Read-only lifecycle visibility for a reference that supports deferred removal.
///
/// Conformance requires no Entity inheritance. Entity projects its lifecycle component
/// through this capability; systems request removal by updating that component directly.
protocol Destructible: AnyObject {
    /// Current registered state, or nil when no live lifecycle is available.
    var lifecycleState: EntityLifecycleState? { get }
}
