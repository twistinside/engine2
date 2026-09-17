@testable import Engine2

/// Supplies a collision target with a lifetime and health independent of launching.
final class ExpiringTargetTestEntity: Entity, Collidable, Expirable, Damageable {}
