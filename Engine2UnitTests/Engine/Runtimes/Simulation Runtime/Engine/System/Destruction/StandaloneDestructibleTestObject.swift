@testable import Engine2

/// Exposes lifecycle state independently of Entity and World.
final class StandaloneDestructibleTestObject: Destructible {
    var lifecycleState: EntityLifecycleState? = .active
}
