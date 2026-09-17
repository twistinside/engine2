/// Shared response eligibility for contact effects and physical bounce.
///
/// Detection retains every geometric contact. Responses require active participants, the source's
/// authored contact scope, and each participant's owner policy. Physical bounce separately requires
/// solid participants; sensor response alone does not prevent an entity from receiving damage.
struct CollisionContactFilter {
    func allowsResponse(from source: EntityID, to target: EntityID, in world: World) -> Bool {
        guard source != target,
              world.components[DestructibleComponent.self][source]?.state == .active,
              world.components[DestructibleComponent.self][target]?.state == .active,
              let sourceBody = world.components[CollisionBodyComponent.self][source],
              let targetBody = world.components[CollisionBodyComponent.self][target] else {
            return false
        }
        if sourceBody.contactScope == .solidBodies && !targetBody.response.isSolid {
            return false
        }
        if sourceBody.ownerPolicy == .exclude && world.components[OwnershipComponent.self][source]?.ownerEntityID == target {
            return false
        }
        if targetBody.ownerPolicy == .exclude && world.components[OwnershipComponent.self][target]?.ownerEntityID == source {
            return false
        }
        return true
    }
}
