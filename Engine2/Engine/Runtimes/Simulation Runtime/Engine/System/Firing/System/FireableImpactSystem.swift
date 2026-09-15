/// Applies fired-body impact policy to generic contacts captured by CollisionSystem.
///
/// Each active fired body selects its earliest eligible contact, excluding its owner and other
/// fired bodies. Both participants are marked only after every fired body has selected,
/// so simultaneous hits against the same target all receive their response.
struct FireableImpactSystem: System {
    mutating func update(world: inout World, deltaTime: Double) {
        guard deltaTime.isFinite, deltaTime > 0 else {
            return
        }

        var impactedEntities: Set<EntityID> = []
        for entity in world.fireableComponents.entities where world.entity(for: entity)?.lifecycleState == .active {
            guard let target = firstImpact(of: entity, in: world) else {
                continue
            }
            impactedEntities.insert(entity)
            impactedEntities.insert(target)
        }
        for entity in impactedEntities.sorted() {
            world.entity(for: entity)?.markForRemoval()
        }
    }

    private func firstImpact(of entity: EntityID, in world: World) -> EntityID? {
        let owner = world.ownershipComponents[entity]?.ownerEntityID
        var hitEntity: EntityID?
        var hitFraction = Double.infinity
        for contact in world.collisionContacts {
            let target: EntityID
            if contact.firstEntityID == entity {
                target = contact.secondEntityID
            } else if contact.secondEntityID == entity {
                target = contact.firstEntityID
            } else {
                continue
            }
            guard target != owner,
                  world.fireableComponents[target] == nil,
                  world.entity(for: target)?.lifecycleState == .active else {
                continue
            }
            if contact.tickFraction < hitFraction ||
                (contact.tickFraction == hitFraction && (hitEntity.map { target < $0 } ?? true)) {
                hitEntity = target
                hitFraction = contact.tickFraction
            }
        }
        return hitEntity
    }
}
