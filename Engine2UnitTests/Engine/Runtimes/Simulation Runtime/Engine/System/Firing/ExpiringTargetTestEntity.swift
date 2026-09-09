@testable import Engine2

/// Supplies a destructible collision target with a lifetime independent of firing.
final class ExpiringTargetTestEntity: Entity, Collidable, Destructible, Expirable {}
