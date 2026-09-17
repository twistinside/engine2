/// Captures collider positions before rail and dynamic movement begin.
struct PreviousPositionCaptureSystem: System {
    mutating func update(world: inout World, deltaTime _: Double) {
        let entities = world.components[PreviousPositionComponent.self].entities
        for entity in entities {
            guard let position = world.components[PositionComponent.self][entity]?.position else {
                continue
            }
            world.components[PreviousPositionComponent.self].update(for: entity) { previous in
                previous.position = position
            }
        }
    }
}
