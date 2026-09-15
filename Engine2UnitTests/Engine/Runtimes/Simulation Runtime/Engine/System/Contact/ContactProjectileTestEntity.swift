@testable import Engine2

/// Combines movement, contact damage, and consumption without ownership or lifetime.
final class ContactProjectileTestEntity: Entity, Movable, ContactDamaging, ContactConsumable {}
