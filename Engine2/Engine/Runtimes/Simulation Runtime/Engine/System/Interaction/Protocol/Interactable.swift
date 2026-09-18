/// Capability for positioned entity facades that accept proximity interaction.
protocol Interactable: Positionable {
    var interactionRange: Double { get }
}

extension Interactable {
    var interactionRange: Double {
        guard let interaction = world.components[InteractionComponent.self][id] else {
            fatalError("There is no interaction component for the interactable entity with ID: \(id)")
        }
        return interaction.interactionRange
    }
}
