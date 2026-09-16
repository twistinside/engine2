import simd

/// Applies bounce response to the earliest eligible contact for each active dynamic body.
///
/// Sensors do not bounce or act as bounce obstacles. Dynamic component order preserves the
/// existing sequential response policy. Each positional correction updates local contact candidates
/// involving that body, so later bodies see its corrected path and the original tick's lifetime bounds.
/// World retains the initial detection facts for other consumers.
struct CollisionResponseSystem: System {
    private let evaluator = CollisionEvaluator()
    private let contactFilter = CollisionContactFilter()

    mutating func update(world: inout World, deltaTime: Double) {
        guard deltaTime.isFinite, deltaTime > 0 else {
            return
        }

        var contacts = world.collisionContacts
        var sweeps = world.collisionSweeps
        for entity in world.motionComponents.entities {
            guard world.lifecycleComponents[entity]?.state == .active,
                  world.collisionBodyComponents[entity]?.response.isSolid == true,
                  let sweepIndex = sweeps.firstIndex(where: { $0.entityID == entity }),
                  let contact = earliestContact(for: entity, among: contacts, in: world),
                  let position = resolve(contact, for: entity, in: world) else {
                continue
            }
            if position != sweeps[sweepIndex].position {
                sweeps[sweepIndex].position = position
                refreshContacts(after: sweeps[sweepIndex], sweeps: sweeps, contacts: &contacts, in: world)
            }
        }
    }

    private func earliestContact(
        for entity: EntityID,
        among contacts: [CollisionContact],
        in world: World
    ) -> CollisionContact? {
        var earliest: CollisionContact?
        var earliestObstacle: EntityID?
        var earliestFraction = Double.infinity
        for contact in contacts where contact.firstEntityID == entity || contact.secondEntityID == entity {
            let obstacle = contact.firstEntityID == entity ? contact.secondEntityID : contact.firstEntityID
            guard world.collisionBodyComponents[obstacle]?.response.isSolid == true,
                  contactFilter.allowsResponse(from: entity, to: obstacle, in: world) else {
                continue
            }
            if contact.tickFraction < earliestFraction ||
                (contact.tickFraction == earliestFraction && (earliestObstacle.map { obstacle < $0 } ?? true)) {
                earliest = contact
                earliestObstacle = obstacle
                earliestFraction = contact.tickFraction
            }
        }
        return earliest
    }

    private func resolve(_ contact: CollisionContact, for entity: EntityID, in world: World) -> SIMD2<Double>? {
        let obstacle = contact.firstEntityID == entity ? contact.secondEntityID : contact.firstEntityID
        let normal = contact.firstEntityID == entity ? contact.normal : -contact.normal
        guard let body = world.collisionBodyComponents[entity],
              let obstacleBody = world.collisionBodyComponents[obstacle],
              let restitution = body.response.restitution,
              let obstacleRestitution = obstacleBody.response.restitution,
              let obstaclePosition = world.positionComponents[obstacle]?.position,
              world.positionComponents[entity] != nil,
              let motion = world.motionComponents[entity] else {
            return nil
        }

        let position = SIMD2<Double>(obstaclePosition.x, obstaclePosition.y) + normal * (body.radius + obstacleBody.radius)
        world.positionComponents.update(for: entity) { component in
            component.position.x = position.x
            component.position.y = position.y
        }

        let obstacleVelocity = velocity(of: obstacle, in: world)
        let relativeVelocity = SIMD2<Double>(
            motion.velocity.x - obstacleVelocity.x,
            motion.velocity.y - obstacleVelocity.y
        )
        let normalVelocity = simd_dot(relativeVelocity, normal)
        guard normalVelocity < 0 else {
            return position
        }

        let reflectedVelocity = relativeVelocity - (1 + min(restitution, obstacleRestitution)) * normalVelocity * normal
        world.motionComponents.update(for: entity) { component in
            component.velocity.x = obstacleVelocity.x + reflectedVelocity.x
            component.velocity.y = obstacleVelocity.y + reflectedVelocity.y
        }
        return position
    }

    private func refreshContacts(
        after changed: CollisionSweep,
        sweeps: [CollisionSweep],
        contacts: inout [CollisionContact],
        in world: World
    ) {
        contacts.removeAll { $0.firstEntityID == changed.entityID || $0.secondEntityID == changed.entityID }
        for obstacle in sweeps where obstacle.entityID != changed.entityID {
            guard world.lifecycleComponents[obstacle.entityID]?.state == .active else {
                continue
            }
            if let contact = evaluator.contact(between: changed, and: obstacle) {
                contacts.append(contact)
            }
        }
    }

    private func velocity(of entity: EntityID, in world: World) -> SIMD2<Double> {
        if let rail = world.orbitalRailComponents[entity] {
            return SIMD2<Double>(rail.velocity.x, rail.velocity.y)
        }
        if let motion = world.motionComponents[entity] {
            return SIMD2<Double>(motion.velocity.x, motion.velocity.y)
        }
        return .zero
    }
}
