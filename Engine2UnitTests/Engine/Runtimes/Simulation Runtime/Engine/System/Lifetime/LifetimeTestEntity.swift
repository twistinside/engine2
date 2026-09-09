@testable import Engine2

/// Isolates finite lifetime from physics, ownership, firing, and destructibility.
final class LifetimeTestEntity: Entity, Expirable {}
