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

        #expect(scene.world.contactConsumptionComponents.entities == [first.id, second.id, third.id])
        for missile in [first, second, third] {
            #expect(scene.world.entity(for: missile.id) === missile)
            #expect(scene.world.lifetimeComponents[missile.id]?.remainingLifetime == 0)
            #expect(missile.lifecycleState == .pendingRemoval)
            #expect(scene.world.motionComponents[missile.id] != nil)
            #expect(scene.world.collisionBodyComponents[missile.id] != nil)
            #expect(scene.world.renderableComponents[missile.id] != nil)
        }

        var removal = EntityRemovalSystem()
        removal.update(world: &scene.world, deltaTime: 1)

        #expect(first.lifecycleState == nil)
        #expect(second.lifecycleState == nil)
        #expect(third.lifecycleState == nil)
        #expect(scene.world.entity(for: first.id) == nil)
        #expect(scene.world.entity(for: second.id) == nil)
        #expect(scene.world.entity(for: third.id) == nil)
        #expect(scene.world.contactConsumptionComponents.entities.isEmpty)
        #expect(scene.world.motionComponents.entities == [scene.skiff.id])
    }

    @Test func repeatedExpiryKeepsLifetimeAtZeroAndPendingRemovalState() {
        var world = World()
        let entity = LifetimeTestEntity(in: world, from: Entity.InitialState(lifetime: 0.5))
        var system = LifetimeSystem()

        system.update(world: &world, deltaTime: 1)
        system.update(world: &world, deltaTime: 1)

        #expect(world.entity(for: entity.id) === entity)
        #expect(world.lifetimeComponents[entity.id]?.remainingLifetime == 0)
        #expect(entity.lifecycleState == .pendingRemoval)
    }

    @Test func lifetimeOnlyEntityCountsDownAndExpiresWithoutPhysicsOrFiring() {
        var world = World()
        let entity = LifetimeTestEntity(
            in: world,
            from: Entity.InitialState(lifetime: 2)
        )
        #expect(entity.remainingLifetime == 2)
        #expect(world.positionComponents[entity.id] == nil)
        #expect(world.motionComponents[entity.id] == nil)
        #expect(world.collisionBodyComponents[entity.id] == nil)
        #expect(world.ownershipComponents[entity.id] == nil)
        #expect(world.contactConsumptionComponents[entity.id] == nil)

        var system = LifetimeSystem()
        system.update(world: &world, deltaTime: 0.5)

        #expect(world.entity(for: entity.id) === entity)
        #expect(entity.remainingLifetime == 1.5)
        #expect(entity.lifecycleState == .active)

        system.update(world: &world, deltaTime: 1.5)

        #expect(world.entity(for: entity.id) === entity)
        #expect(entity.remainingLifetime == 0)
        #expect(entity.lifecycleState == .pendingRemoval)
        #expect(world.contactConsumptionComponents[entity.id] == nil)

        var removal = EntityRemovalSystem()
        removal.update(world: &world, deltaTime: 1.5)

        #expect(entity.lifecycleState == nil)
        #expect(world.entity(for: entity.id) == nil)
        #expect(world.lifetimeComponents[entity.id] == nil)
    }
}
