import Testing
@testable import Engine2

struct FireableTests {
    @Test func firingAndDestructibilityDoNotRequireCollisionOrMovement() {
        var world = World()
        let entity = NonphysicalFireableTestEntity(
            in: world,
            from: Entity.InitialState(destructible: DestructibleComponent(), fireable: FireableComponent())
        )
        #expect(world.fireableComponents[entity.id] != nil)
        #expect(world.destructibleComponents[entity.id] != nil)
        #expect(world.positionComponents[entity.id] == nil)
        #expect(world.motionComponents[entity.id] == nil)
        #expect(world.collisionBodyComponents[entity.id] == nil)
        #expect(world.ownershipComponents[entity.id] == nil)
        #expect(world.lifetimeComponents[entity.id] == nil)

        var system = FireableImpactSystem()
        system.update(world: &world, deltaTime: 1)

        #expect(world.entity(for: entity.id) === entity)
    }
}
