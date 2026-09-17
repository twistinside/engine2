import Testing
@testable import Engine2

struct DestructibleTests {
    @Test func baseEntityExposesComponentStateThroughTheProtocolUntilFinalCollection() {
        var world = World()
        let entity = Entity(in: world, from: .empty)
        let destructible: any Destructible = entity
        #expect(destructible.lifecycleState == .active)
        #expect(world.components[PositionComponent.self][entity.id] == nil)
        #expect(world.components[MotionComponent.self][entity.id] == nil)
        #expect(world.components[CollisionBodyComponent.self][entity.id] == nil)
        #expect(world.components[ContactConsumptionComponent.self][entity.id] == nil)
        #expect(world.components[OwnershipComponent.self][entity.id] == nil)
        #expect(world.components[LifetimeComponent.self][entity.id] == nil)

        #expect(world.components[DestructibleComponent.self].update(for: entity.id) { $0.state = .pendingRemoval })

        #expect(destructible.lifecycleState == .pendingRemoval)
        #expect(world.entity(for: entity.id) === entity)

        var removal = EntityRemovalSystem()
        removal.update(world: &world, deltaTime: 1)

        #expect(destructible.lifecycleState == nil)
        #expect(world.components[DestructibleComponent.self][entity.id] == nil)
        #expect(world.entity(for: entity.id) == nil)
    }

    @Test func subclassInheritsDestructionWithoutDeclaringConformance() {
        var world = World()
        let entity = InheritedDestructibleTestEntity(in: world, from: .empty)
        let destructible: any Destructible = entity
        #expect(destructible.lifecycleState == .active)

        #expect(world.components[DestructibleComponent.self].update(for: entity.id) { $0.state = .pendingRemoval })

        #expect(destructible.lifecycleState == .pendingRemoval)
        #expect(world.entity(for: entity.id) === entity)

        var removal = EntityRemovalSystem()
        removal.update(world: &world, deltaTime: 1)

        #expect(destructible.lifecycleState == nil)
        #expect(world.components[DestructibleComponent.self][entity.id] == nil)
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
