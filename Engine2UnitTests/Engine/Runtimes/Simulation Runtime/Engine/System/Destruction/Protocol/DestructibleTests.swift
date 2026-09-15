import Testing
@testable import Engine2

struct DestructibleTests {
    @Test func baseEntityAcceptsDestructionThroughTheProtocolUntilFinalCollection() {
        var world = World()
        let entity = Entity(in: world, from: .empty)
        let destructible: any Destructible = entity
        #expect(entity.lifecycleState == .active)
        #expect(world.positionComponents[entity.id] == nil)
        #expect(world.motionComponents[entity.id] == nil)
        #expect(world.collisionBodyComponents[entity.id] == nil)
        #expect(world.contactConsumptionComponents[entity.id] == nil)
        #expect(world.ownershipComponents[entity.id] == nil)
        #expect(world.lifetimeComponents[entity.id] == nil)

        #expect(destructible.markForRemoval())
        #expect(destructible.markForRemoval())

        #expect(entity.lifecycleState == .pendingRemoval)
        #expect(world.entity(for: entity.id) === entity)

        var removal = EntityRemovalSystem()
        removal.update(world: &world, deltaTime: 1)

        #expect(entity.lifecycleState == .removed)
        #expect(world.entity(for: entity.id) == nil)
        #expect(destructible.markForRemoval() == false)
    }

    @Test func subclassInheritsDestructionWithoutDeclaringConformance() {
        var world = World()
        let entity = InheritedDestructibleTestEntity(in: world, from: .empty)
        let destructible: any Destructible = entity

        #expect(destructible.markForRemoval())
        #expect(entity.lifecycleState == .pendingRemoval)
        #expect(world.entity(for: entity.id) === entity)

        var removal = EntityRemovalSystem()
        removal.update(world: &world, deltaTime: 1)

        #expect(entity.lifecycleState == .removed)
        #expect(world.entity(for: entity.id) == nil)
    }

    @Test func protocolAcceptsAnImplementationIndependentOfEntity() {
        let object = StandaloneDestructibleTestObject()
        let destructible: any Destructible = object
        #expect(object.removalRequested == false)

        #expect(destructible.markForRemoval())

        #expect(object.removalRequested)
    }
}
