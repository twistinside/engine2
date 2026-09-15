@testable import Engine2

/// Deliberately conflicting capabilities used to verify spawn-policy rejection.
final class InitialStateDynamicRailEntity: Entity, Orbiting, Movable {}
