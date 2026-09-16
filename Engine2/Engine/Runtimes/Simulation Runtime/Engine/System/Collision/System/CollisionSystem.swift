/// Captures every intersecting pair of active planar collision bodies without applying gameplay policy.
///
/// Ownership and response policies do not affect geometric detection. Consumers select eligible
/// contacts before choosing their earliest response. Every update replaces the World's collision data,
/// including invalid-duration updates; final entity collection clears it after all consumers finish.
struct CollisionSystem: System {
    private let evaluator = CollisionEvaluator()

    mutating func update(world: inout World, deltaTime: Double) {
        world.collisionContacts.removeAll(keepingCapacity: true)
        world.collisionSweeps.removeAll(keepingCapacity: true)
        guard deltaTime.isFinite, deltaTime > 0 else {
            return
        }

        captureSweeps(in: world, deltaTime: deltaTime)
        for index in world.collisionSweeps.indices {
            let first = world.collisionSweeps[index]
            for second in world.collisionSweeps[(index + 1)...] {
                if let contact = evaluator.contact(between: first, and: second) {
                    world.collisionContacts.append(contact)
                }
            }
        }
    }

    private func captureSweeps(in world: World, deltaTime: Double) {
        for entity in world.collisionBodyComponents.entities.sorted() {
            guard world.lifecycleComponents[entity]?.state == .active,
                  let body = world.collisionBodyComponents[entity],
                  let previous = world.previousPositionComponents[entity]?.position,
                  let current = world.positionComponents[entity]?.position,
                  previous.isFinite, current.isFinite else {
                continue
            }
            let travelFraction = world.lifetimeComponents[entity].map {
                min(1, max(0, $0.remainingLifetime / deltaTime))
            } ?? 1
            guard travelFraction > 0 else {
                continue
            }
            world.collisionSweeps.append(
                CollisionSweep(
                    entityID: entity,
                    previousPosition: SIMD2<Double>(previous.x, previous.y),
                    position: SIMD2<Double>(current.x, current.y),
                    radius: body.radius,
                    travelFraction: travelFraction
                )
            )
        }
    }
}
