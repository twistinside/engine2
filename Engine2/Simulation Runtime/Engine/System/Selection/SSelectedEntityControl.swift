import simd

/// Routes held semantic commands only to the selected controllable entity.
///
/// Clearing every control row first guarantees that changing selection to a
/// non-controllable entity removes the previous skiff command on that tick.
struct SSelectedEntityControl: PSystem {
    mutating func update(world: inout World, deltaTime _: Double) {
        for entity in world.playerControlComponents.entities {
            world.playerControlComponents.update(for: entity) { control in
                control.translation = .zero
                control.interactionState = .inactive
            }
        }

        guard let selectedEntityID = world.selectedEntityID else {
            return
        }

        let translation = SIMD2<Double>(world.input.translation)
        let interactionState: PlayerInteractionState = world.input.isInteractionActive ? .active : .inactive
        world.playerControlComponents.update(for: selectedEntityID) { control in
            control.translation = translation
            control.interactionState = interactionState
        }
    }
}
