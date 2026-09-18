/// Position captured before rail and dynamic motion for swept collision tests.
struct PreviousPositionComponent: Component {
    var position: SIMD3<Double>
}

extension PreviousPositionComponent {
    @MainActor init?(for entity: Entity, from state: Entity.InitialState) {
        guard entity is Collidable else { return nil }
        guard let position = entity.world.components[PositionComponent.self][entity.id]?.position else {
            preconditionFailure("A collidable entity requires its resolved position before collision registration.")
        }
        self.init(position: position)
    }
}
