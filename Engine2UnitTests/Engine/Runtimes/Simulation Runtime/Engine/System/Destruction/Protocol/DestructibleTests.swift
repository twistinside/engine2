import Testing
@testable import Engine2

struct DestructibleTests {
    @Test func destructibilityOnlyEntityRegistersAndRemovesWithoutPhysics() {
        let world = World()
        let entity = DestructibleTestEntity(
            in: world,
            from: Entity.InitialState(destructible: DestructibleComponent())
        )
        #expect(world.entity(for: entity.id) === entity)
        #expect(world.destructibleComponents[entity.id] != nil)
        #expect(world.positionComponents[entity.id] == nil)
        #expect(world.motionComponents[entity.id] == nil)
        #expect(world.collisionBodyComponents[entity.id] == nil)
        #expect(world.fireableComponents[entity.id] == nil)
        #expect(world.ownershipComponents[entity.id] == nil)
        #expect(world.lifetimeComponents[entity.id] == nil)

        #expect(world.destroy(entity.id))

        #expect(world.entity(for: entity.id) == nil)
        #expect(world.destructibleComponents[entity.id] == nil)
    }
}
