@testable import Engine2

/// Isolates firing and destructibility markers from positioned collision state.
final class NonphysicalFireableTestEntity: Entity, Fireable, Destructible {}
