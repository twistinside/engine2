/// Authored physical response independent of damage, ownership, or removal capabilities.
///
/// Solid bodies obstruct other solid bodies and may bounce. Sensors produce geometric contacts
/// without physical bounce. Contact scope and health independently control effects and damage.
nonisolated enum CollisionResponse: Codable, Equatable, Sendable {
    case solid(restitution: Double)
    case sensor

    var isSolid: Bool {
        if case .solid = self { return true }
        return false
    }

    var restitution: Double? {
        if case let .solid(restitution) = self { return restitution }
        return nil
    }
}
