import Testing
@testable import Engine2

struct FireableTests {
    @Test func firingDoesNotRequireCollisionOrMovement() {
        var world = World()
        let entity = NonphysicalFireableTestEntity(
            in: world,
            from: .empty
        )
        #expect(world.fireableComponents[entity.id] != nil)
        #expect(world.positionComponents[entity.id] == nil)
        #expect(world.motionComponents[entity.id] == nil)
        #expect(world.collisionBodyComponents[entity.id] == nil)
        #expect(world.ownershipComponents[entity.id] == nil)
        #expect(world.lifetimeComponents[entity.id] == nil)

        var detector = CollisionSystem()
        detector.update(world: &world, deltaTime: 1)
        #expect(world.collisionContacts.isEmpty)
        var response = FireableImpactSystem()
        response.update(world: &world, deltaTime: 1)
        #expect(world.registeredEntities.allSatisfy { $0.lifecycleState == .active })
        var removal = EntityRemovalSystem()
        removal.update(world: &world, deltaTime: 1)

        #expect(world.entity(for: entity.id) === entity)
    }
}
