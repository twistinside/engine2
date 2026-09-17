/// Determines whether responses include contact with an entity's attributed owner.
/// Ownership alone does not grant contact immunity; exclusion compares the complete EntityID.
nonisolated enum CollisionOwnerPolicy: Codable, Equatable, Sendable {
    case include
    case exclude
}
