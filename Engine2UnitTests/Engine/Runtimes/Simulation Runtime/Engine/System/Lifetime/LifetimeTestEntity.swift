@testable import Engine2

/// Isolates finite lifetime from physics, ownership, and firing.
final class LifetimeTestEntity: Entity, Expirable {}
