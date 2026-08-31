/// Captures collider positions before rail and dynamic movement begin.
struct SPreviousPositionCapture: PSystem {
    mutating func update(world: inout World, deltaTime _: Double) {
        let entities = world.previousPositionComponents.entities
        for entity in entities {
            guard let position = world.positionComponents[entity]?.position else {
                continue
            }
            world.previousPositionComponents.update(for: entity) { previous in
                previous.position = position
            }
        }
    }
}
