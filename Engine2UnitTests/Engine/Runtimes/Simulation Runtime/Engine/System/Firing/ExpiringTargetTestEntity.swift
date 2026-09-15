@testable import Engine2

/// Supplies a collision target with a lifetime independent of firing.
final class ExpiringTargetTestEntity: Entity, Collidable, Expirable {}
