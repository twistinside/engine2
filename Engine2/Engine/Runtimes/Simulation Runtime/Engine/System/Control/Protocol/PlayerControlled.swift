/// Capability for entity facades that expose selected semantic command state.
protocol PlayerControlled: Entity {
    var interactionState: PlayerInteractionState { get }
    var translationIntent: SIMD2<Double> { get }
}

extension PlayerControlled {
    var interactionState: PlayerInteractionState {
        guard let control = world.components[PlayerControlComponent.self][id] else {
            fatalError("There is no player control component for the controlled entity with ID: \(id)")
        }
        return control.interactionState
    }

    var translationIntent: SIMD2<Double> {
        guard let control = world.components[PlayerControlComponent.self][id] else {
            fatalError("There is no player control component for the controlled entity with ID: \(id)")
        }
        return control.translation
    }
}
