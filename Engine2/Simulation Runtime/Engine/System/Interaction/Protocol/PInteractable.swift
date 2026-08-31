/// Capability for positioned entity facades that accept proximity interaction.
protocol PInteractable: PPositionable {
    var interactionRange: Double { get }
}

extension PInteractable {
    var interactionRange: Double {
        guard let interaction = world.interactionComponents[id] else {
            fatalError("There is no interaction component for the interactable entity with ID: \(id)")
        }
        return interaction.interactionRange
    }
}
