/// Capability for resource entities that accept proximity mining interaction.
protocol Mineable: OreContaining, Interactable {
    var miningRate: Double { get }
}

extension Mineable {
    var miningRate: Double {
        guard let mineable = world.mineableComponents[id] else {
            fatalError("There is no mineable component for the mineable entity with ID: \(id)")
        }
        return mineable.miningRate
    }
}
