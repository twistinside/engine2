/// Advances deterministic circular rails by deriving each complete orbit state.
struct SOrbitalRail: PSystem {
    mutating func update(world: inout World, deltaTime: Double) {
        guard deltaTime.isFinite, deltaTime > 0 else {
            return
        }

        let entities = world.orbitalRailComponents.entities
        for entity in entities {
            guard var rail = world.orbitalRailComponents[entity],
                  let primaryPosition = world.positionComponents[rail.primaryEntityID]?.position else {
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
            world.orbitalRailComponents.update(for: entity) { component in
                component = rail
            }
            world.positionComponents.update(for: entity) { position in
                position.position = state.position
            }
        }
    }
}
