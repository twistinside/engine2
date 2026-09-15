/// Shared response eligibility for contact effects and physical bounce.
///
/// Detection retains every geometric contact. Responses require active participants, the source's
/// authored contact scope, and each participant's owner policy. Physical bounce separately requires
/// solid participants; sensor response alone does not prevent an entity from receiving damage.
struct CollisionContactFilter {
    func allowsResponse(from source: EntityID, to target: EntityID, in world: World) -> Bool {
        guard source != target,
              world.entity(for: source)?.lifecycleState == .active,
              world.entity(for: target)?.lifecycleState == .active,
              let sourceBody = world.collisionBodyComponents[source],
              let targetBody = world.collisionBodyComponents[target] else {
            return false
        }
        if sourceBody.contactScope == .solidBodies && !targetBody.response.isSolid {
            return false
        }
        if sourceBody.ownerPolicy == .exclude && world.ownershipComponents[source]?.ownerEntityID == target {
            return false
        }
        if targetBody.ownerPolicy == .exclude && world.ownershipComponents[target]?.ownerEntityID == source {
            return false
        }
        return true
    }
}
