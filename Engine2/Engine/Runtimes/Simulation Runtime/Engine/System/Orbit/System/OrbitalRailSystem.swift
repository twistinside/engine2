/// Advances deterministic circular rails by deriving each complete orbit state.
struct OrbitalRailSystem: System {
    mutating func update(world: inout World, deltaTime: Double) {
        guard deltaTime.isFinite, deltaTime > 0 else {
            return
        }

        let entities = world.components[OrbitalRailComponent.self].entities
        for entity in entities {
            guard var rail = world.components[OrbitalRailComponent.self][entity],
                  let primaryPosition = world.components[PositionComponent.self][rail.primaryEntityID]?.position else {
                continue
            }

            rail.elapsedTime += deltaTime
            let state = rail.state(relativeTo: primaryPosition)
            guard rail.elapsedTime.isFinite,
                  state.position.isFinite,
                  state.velocity.isFinite else {
                continue
            }

            rail.velocity = state.velocity
            world.components[OrbitalRailComponent.self].update(for: entity) { component in
                component = rail
            }
            world.components[PositionComponent.self].update(for: entity) { position in
                position.position = state.position
            }
        }
    }
}
