@testable import Engine2

/// Supplies only the independent capabilities required by fired-body impact tests.
final class DestructibleFireableTestEntity: Entity, Fireable, Destructible, Movable, Collidable {}
