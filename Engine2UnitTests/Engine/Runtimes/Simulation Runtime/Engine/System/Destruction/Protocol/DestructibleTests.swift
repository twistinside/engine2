import Testing
@testable import Engine2

struct DestructibleTests {
    @Test func baseEntityExposesComponentStateThroughTheProtocolUntilFinalCollection() {
        var world = World()
        let entity = Entity(in: world, from: .empty)
        let destructible: any Destructible = entity
        #expect(destructible.lifecycleState == .active)
        #expect(world.positionComponents[entity.id] == nil)
        #expect(world.motionComponents[entity.id] == nil)
        #expect(world.collisionBodyComponents[entity.id] == nil)
        #expect(world.contactConsumptionComponents[entity.id] == nil)
        #expect(world.ownershipComponents[entity.id] == nil)
        #expect(world.lifetimeComponents[entity.id] == nil)

        #expect(world.lifecycleComponents.update(for: entity.id) { $0.state = .pendingRemoval })

        #expect(destructible.lifecycleState == .pendingRemoval)
        #expect(world.entity(for: entity.id) === entity)

        var removal = EntityRemovalSystem()
        removal.update(world: &world, deltaTime: 1)

        #expect(destructible.lifecycleState == nil)
        #expect(world.lifecycleComponents[entity.id] == nil)
        #expect(world.entity(for: entity.id) == nil)
    }

    @Test func subclassInheritsDestructionWithoutDeclaringConformance() {
        var world = World()
        let entity = InheritedDestructibleTestEntity(in: world, from: .empty)
        let destructible: any Destructible = entity
        #expect(destructible.lifecycleState == .active)

        #expect(world.lifecycleComponents.update(for: entity.id) { $0.state = .pendingRemoval })

        #expect(destructible.lifecycleState == .pendingRemoval)
        #expect(world.entity(for: entity.id) === entity)

        var removal = EntityRemovalSystem()
        removal.update(world: &world, deltaTime: 1)

        #expect(destructible.lifecycleState == nil)
        #expect(world.lifecycleComponents[entity.id] == nil)
        #expect(world.entity(for: entity.id) == nil)
    }

    @Test func protocolAcceptsAnImplementationIndependentOfEntity() {
        let object = StandaloneDestructibleTestObject()
        let destructible: any Destructible = object
        #expect(destructible.lifecycleState == .active)

        object.lifecycleState = .pendingRemoval

        #expect(destructible.lifecycleState == .pendingRemoval)
    }
}
