/// Capability for resource entities that accept proximity mining interaction.
protocol PMineable: POreContaining, PPositionable {
    var interactionRange: Double { get }
    var miningRate: Double { get }
}

extension PMineable {
    var interactionRange: Double {
        guard let mineable = world.mineableComponents[id] else {
            fatalError("There is no mineable component for the mineable entity with ID: \(id)")
        }
        return mineable.interactionRange
    }

    var miningRate: Double {
        guard let mineable = world.mineableComponents[id] else {
            fatalError("There is no mineable component for the mineable entity with ID: \(id)")
        }
        return mineable.miningRate
    }
}
