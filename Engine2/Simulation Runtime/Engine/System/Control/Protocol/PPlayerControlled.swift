/// Capability for entity facades that expose selected semantic command state.
protocol PPlayerControlled: Entity {
    var interactionState: PlayerInteractionState { get }
    var translationIntent: SIMD2<Double> { get }
}

extension PPlayerControlled {
    var interactionState: PlayerInteractionState {
        guard let control = world.playerControlComponents[id] else {
            fatalError("There is no player control component for the controlled entity with ID: \(id)")
        }
        return control.interactionState
    }

    var translationIntent: SIMD2<Double> {
        guard let control = world.playerControlComponents[id] else {
            fatalError("There is no player control component for the controlled entity with ID: \(id)")
        }
        return control.translation
    }
}
