import Testing
@testable import Engine2

struct LifetimeSystemTests {
    @Test func expiryMarksEveryMissileAndRetainsRowsUntilCollection() {
        var scene = MissileTestScene(velocity: .zero)
        let first = scene.missile(at: .zero, velocity: .zero, lifetime: 0.5)
        let second = scene.missile(at: .zero, velocity: .zero, lifetime: 0.5)
        let third = scene.missile(at: .zero, velocity: .zero, lifetime: 0.5)

        var system = LifetimeSystem()
        system.update(world: &scene.world, deltaTime: 1)

        #expect(scene.world.components[ContactConsumptionComponent.self].entities == [first.id, second.id, third.id])
        for missile in [first, second, third] {
            #expect(scene.world.entity(for: missile.id) === missile)
            #expect(scene.world.components[LifetimeComponent.self][missile.id]?.remainingLifetime == 0)
            #expect(missile.lifecycleState == .pendingRemoval)
            #expect(scene.world.components[MotionComponent.self][missile.id] != nil)
            #expect(scene.world.components[CollisionBodyComponent.self][missile.id] != nil)
            #expect(scene.world.components[RenderableComponent.self][missile.id] != nil)
        }

        var removal = EntityRemovalSystem()
        removal.update(world: &scene.world, deltaTime: 1)

        #expect(first.lifecycleState == nil)
        #expect(second.lifecycleState == nil)
        #expect(third.lifecycleState == nil)
        #expect(scene.world.entity(for: first.id) == nil)
        #expect(scene.world.entity(for: second.id) == nil)
        #expect(scene.world.entity(for: third.id) == nil)
        #expect(scene.world.components[ContactConsumptionComponent.self].entities.isEmpty)
        #expect(scene.world.components[MotionComponent.self].entities == [scene.skiff.id])
    }

    @Test func repeatedExpiryKeepsLifetimeAtZeroAndPendingRemovalState() {
        var world = World()
        let entity = LifetimeTestEntity(in: world, from: Entity.InitialState(lifetime: 0.5))
        var system = LifetimeSystem()

        system.update(world: &world, deltaTime: 1)
        system.update(world: &world, deltaTime: 1)

        #expect(world.entity(for: entity.id) === entity)
        #expect(world.components[LifetimeComponent.self][entity.id]?.remainingLifetime == 0)
        #expect(entity.lifecycleState == .pendingRemoval)
    }

    @Test func lifetimeOnlyEntityCountsDownAndExpiresWithoutPhysicsOrFiring() {
        var world = World()
        let entity = LifetimeTestEntity(
            in: world,
            from: Entity.InitialState(lifetime: 2)
        )
        #expect(entity.remainingLifetime == 2)
        #expect(world.components[PositionComponent.self][entity.id] == nil)
        #expect(world.components[MotionComponent.self][entity.id] == nil)
        #expect(world.components[CollisionBodyComponent.self][entity.id] == nil)
        #expect(world.components[OwnershipComponent.self][entity.id] == nil)
        #expect(world.components[ContactConsumptionComponent.self][entity.id] == nil)

        var system = LifetimeSystem()
        system.update(world: &world, deltaTime: 0.5)

        #expect(world.entity(for: entity.id) === entity)
        #expect(entity.remainingLifetime == 1.5)
        #expect(entity.lifecycleState == .active)

        system.update(world: &world, deltaTime: 1.5)

        #expect(world.entity(for: entity.id) === entity)
        #expect(entity.remainingLifetime == 0)
        #expect(entity.lifecycleState == .pendingRemoval)
        #expect(world.components[ContactConsumptionComponent.self][entity.id] == nil)

        var removal = EntityRemovalSystem()
        removal.update(world: &world, deltaTime: 1.5)

        #expect(entity.lifecycleState == nil)
        #expect(world.entity(for: entity.id) == nil)
        #expect(world.components[LifetimeComponent.self][entity.id] == nil)
    }
}
