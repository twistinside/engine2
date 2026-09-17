@testable import Engine2

/// Exchanges contact damage with other solid bodies without being consumed automatically.
final class ContactDamageableTestEntity: Entity, ContactDamaging, Damageable {}
