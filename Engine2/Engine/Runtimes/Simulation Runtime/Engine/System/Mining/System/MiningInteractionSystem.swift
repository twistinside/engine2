import simd

/// Transfers resources with the nearest eligible mineable body or depot.
///
/// Distance wins before full entity identity, giving simultaneous candidates a
/// deterministic result. Depot service unloads ore and refuels from its
/// infinite supply during the same held interaction interval.
struct MiningInteractionSystem: System {
    mutating func update(world: inout World, deltaTime: Double) {
        guard deltaTime.isFinite, deltaTime > 0 else {
            return
        }

        let actors = world.components[PlayerControlComponent.self].entities
        for actor in actors where world.components[DestructibleComponent.self][actor]?.state == .active {
            interact(actor: actor, in: world, deltaTime: deltaTime)
        }
    }

    private func interact(actor: EntityID, in world: World, deltaTime: Double) {
        guard world.components[PlayerControlComponent.self][actor]?.interactionState == .active,
              let actorPosition = world.components[PositionComponent.self][actor]?.position else {
            return
        }

        let cargo = world.components[CargoComponent.self][actor]
        let fuel = world.components[FuelComponent.self][actor]
        var target: EntityID?
        var targetIsMineable = false
        var nearestDistance = Double.infinity

        if let cargo, cargo.ore < cargo.capacity {
            for candidate in world.components[MineableComponent.self].entities where world.components[DestructibleComponent.self][candidate]?.state == .active {
                guard let interaction = world.components[InteractionComponent.self][candidate],
                      let deposit = world.components[OreDepositComponent.self][candidate],
                      deposit.remainingOre > 0,
                      let position = world.components[PositionComponent.self][candidate]?.position else {
                    continue
                }
                let distance = planarDistance(from: actorPosition, to: position)
                guard distance <= interaction.interactionRange else {
                    continue
                }
                if isPreferred(candidate, distance: distance, over: target, distance: nearestDistance) {
                    target = candidate
                    targetIsMineable = true
                    nearestDistance = distance
                }
            }
        }

        if (cargo?.ore ?? 0) > 0 || (fuel.map { $0.remaining < $0.capacity } ?? false) {
            for candidate in world.components[DepotServiceComponent.self].entities where
                world.components[DestructibleComponent.self][candidate]?.state == .active {
                guard let interaction = world.components[InteractionComponent.self][candidate],
                      let position = world.components[PositionComponent.self][candidate]?.position else {
                    continue
                }
                let distance = planarDistance(from: actorPosition, to: position)
                guard distance <= interaction.interactionRange else {
                    continue
                }
                if isPreferred(candidate, distance: distance, over: target, distance: nearestDistance) {
                    target = candidate
                    targetIsMineable = false
                    nearestDistance = distance
                }
            }
        }

        guard let target else {
            return
        }
        if targetIsMineable {
            mine(target, into: actor, in: world, deltaTime: deltaTime)
        } else {
            service(actor, at: target, in: world, deltaTime: deltaTime)
        }
    }

    private func mine(_ source: EntityID, into actor: EntityID, in world: World, deltaTime: Double) {
        guard let mineable = world.components[MineableComponent.self][source],
              let deposit = world.components[OreDepositComponent.self][source],
              let cargo = world.components[CargoComponent.self][actor] else {
            return
        }

        let amount = min(
            mineable.miningRate * deltaTime,
            min(deposit.remainingOre, cargo.capacity - cargo.ore)
        )
        guard amount > 0 else {
            return
        }
        world.components[OreDepositComponent.self].update(for: source) { component in
            component.remainingOre -= amount
        }
        world.components[CargoComponent.self].update(for: actor) { component in
            component.ore += amount
        }
    }

    private func service(_ actor: EntityID, at depot: EntityID, in world: World, deltaTime: Double) {
        guard let service = world.components[DepotServiceComponent.self][depot] else {
            return
        }

        let unloadedOre = world.components[CargoComponent.self][actor].map {
            min(service.unloadingRate * deltaTime, $0.ore)
        } ?? 0
        let suppliedFuel = world.components[FuelComponent.self][actor].map {
            min(service.refuelingRate * deltaTime, $0.capacity - $0.remaining)
        } ?? 0

        if unloadedOre > 0 {
            world.components[CargoComponent.self].update(for: actor) { component in
                component.ore -= unloadedOre
            }
            world.components[DepotServiceComponent.self].update(for: depot) { component in
                component.deliveredOre += unloadedOre
            }
        }

        if suppliedFuel > 0 {
            world.components[FuelComponent.self].update(for: actor) { component in
                component.remaining += suppliedFuel
            }
        }
    }

    private func planarDistance(from first: SIMD3<Double>, to second: SIMD3<Double>) -> Double {
        simd_length(SIMD2<Double>(first.x - second.x, first.y - second.y))
    }

    private func isPreferred(
        _ candidate: EntityID,
        distance: Double,
        over incumbent: EntityID?,
        distance incumbentDistance: Double
    ) -> Bool {
        guard distance.isFinite else {
            return false
        }
        if distance < incumbentDistance {
            return true
        }
        guard distance == incumbentDistance, let incumbent else {
            return false
        }
        return candidate < incumbent
    }
}
