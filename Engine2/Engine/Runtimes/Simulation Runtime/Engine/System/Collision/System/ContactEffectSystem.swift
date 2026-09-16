/// Applies outgoing damage and source consumption independently to captured collision contacts.
///
/// Every active source selects its first eligible contact before any effects are written. Sources
/// that hit the same recipient therefore all apply their effects, even when one hit exhausts its health.
/// Contact order is resolved by tick fraction and complete recipient identity. Removal remains deferred.
struct ContactEffectSystem: System {
    private let contactFilter = CollisionContactFilter()

    mutating func update(world: inout World, deltaTime: Double) {
        guard deltaTime.isFinite, deltaTime > 0 else {
            return
        }

        let impacts = selectImpacts(in: world)
        applyDamage(for: impacts, in: world)
        markRemovals(for: impacts, in: world)
    }

    private func selectImpacts(in world: World) -> [(source: EntityID, target: EntityID)] {
        let sources = Set(world.contactDamageComponents.entities).union(world.contactConsumptionComponents.entities)
        var impacts: [(source: EntityID, target: EntityID)] = []
        for source in sources.sorted() where world.lifecycleComponents[source]?.state == .active {
            if let target = firstImpact(of: source, in: world) {
                impacts.append((source: source, target: target))
            }
        }
        return impacts
    }

    private func firstImpact(of source: EntityID, in world: World) -> EntityID? {
        var target: EntityID?
        var earliestFraction = Double.infinity
        for contact in world.collisionContacts {
            let candidate: EntityID
            if contact.firstEntityID == source {
                candidate = contact.secondEntityID
            } else if contact.secondEntityID == source {
                candidate = contact.firstEntityID
            } else {
                continue
            }
            guard contactFilter.allowsResponse(from: source, to: candidate, in: world) else {
                continue
            }
            if contact.tickFraction < earliestFraction ||
                (contact.tickFraction == earliestFraction && (target.map { candidate < $0 } ?? true)) {
                target = candidate
                earliestFraction = contact.tickFraction
            }
        }
        return target
    }

    private func applyDamage(for impacts: [(source: EntityID, target: EntityID)], in world: World) {
        for impact in impacts {
            guard let damage = world.contactDamageComponents[impact.source] else {
                continue
            }
            world.healthComponents.update(for: impact.target) { component in
                component.applyDamage(damage.amount)
            }
        }
    }

    private func markRemovals(for impacts: [(source: EntityID, target: EntityID)], in world: World) {
        var removals: Set<EntityID> = []
        for impact in impacts {
            if world.contactConsumptionComponents[impact.source] != nil {
                removals.insert(impact.source)
            }
            if world.healthComponents[impact.target]?.health == .zero {
                removals.insert(impact.target)
            }
        }
        for entity in removals.sorted() {
            world.lifecycleComponents.update(for: entity) {
                $0.state = .pendingRemoval
            }
        }
    }
}
