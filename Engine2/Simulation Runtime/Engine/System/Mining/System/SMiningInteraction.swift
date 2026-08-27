import simd

/// Transfers resources with the nearest eligible mineable body or depot.
///
/// Distance wins before full entity identity, giving simultaneous candidates a
/// deterministic result. Depot service unloads ore and refuels from its
/// infinite supply during the same held interaction interval.
struct SMiningInteraction: PSystem {
    mutating func update(world: inout World, deltaTime: Double) {
        guard deltaTime.isFinite, deltaTime > 0 else {
            return
        }

        let actors = world.playerControlComponents.entities
        for actor in actors {
            interact(actor: actor, in: world, deltaTime: deltaTime)
        }
    }

    private func interact(actor: EntityID, in world: World, deltaTime: Double) {
        guard world.playerControlComponents[actor]?.isInteractionActive == true,
              let actorPosition = world.positionComponents[actor]?.position else {
            return
        }

        let cargo = world.cargoComponents[actor]
        let fuel = world.fuelComponents[actor]
        var target: EntityID?
        var targetIsMineable = false
        var nearestDistance = Double.infinity

        if let cargo, cargo.ore < cargo.capacity {
            for candidate in world.mineableComponents.entities {
                guard let mineable = world.mineableComponents[candidate],
                      let deposit = world.oreDepositComponents[candidate],
                      deposit.remainingOre > 0,
                      let position = world.positionComponents[candidate]?.position else {
                    continue
                }
                let distance = planarDistance(from: actorPosition, to: position)
                guard distance <= mineable.interactionRange else {
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
            for candidate in world.depotServiceComponents.entities {
                guard let depot = world.depotServiceComponents[candidate],
                      let position = world.positionComponents[candidate]?.position else {
                    continue
                }
                let distance = planarDistance(from: actorPosition, to: position)
                guard distance <= depot.interactionRange else {
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
        guard let mineable = world.mineableComponents[source],
              let deposit = world.oreDepositComponents[source],
              let cargo = world.cargoComponents[actor] else {
            return
        }

        let amount = min(
            mineable.miningRate * deltaTime,
            min(deposit.remainingOre, cargo.capacity - cargo.ore)
        )
        guard amount > 0 else {
            return
        }
        world.oreDepositComponents.update(for: source) { component in
            component.remainingOre -= amount
        }
        world.cargoComponents.update(for: actor) { component in
            component.ore += amount
        }
    }

    private func service(_ actor: EntityID, at depot: EntityID, in world: World, deltaTime: Double) {
        guard let service = world.depotServiceComponents[depot] else {
            return
        }

        let unloadedOre = world.cargoComponents[actor].map {
            min(service.unloadingRate * deltaTime, $0.ore)
        } ?? 0
        let suppliedFuel = world.fuelComponents[actor].map {
            min(service.refuelingRate * deltaTime, $0.capacity - $0.remaining)
        } ?? 0

        if unloadedOre > 0 {
            world.cargoComponents.update(for: actor) { component in
                component.ore -= unloadedOre
            }
            world.depotServiceComponents.update(for: depot) { component in
                component.deliveredOre += unloadedOre
            }
        }

        if suppliedFuel > 0 {
            world.fuelComponents.update(for: actor) { component in
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
        if candidate.index == incumbent.index {
            return candidate.generation < incumbent.generation
        }
        return candidate.index < incumbent.index
    }
}
