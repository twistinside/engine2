import Testing
@testable import Engine2

struct LifetimeSystemTests {
    @Test func expiryRemovesEveryMissileWithoutSkippingCompactedRows() {
        var scene = MissileTestScene(velocity: .zero)
        let first = scene.missile(at: .zero, velocity: .zero, lifetime: 0.5)
        let second = scene.missile(at: .zero, velocity: .zero, lifetime: 0.5)
        let third = scene.missile(at: .zero, velocity: .zero, lifetime: 0.5)

        var system = LifetimeSystem()
        system.update(world: &scene.world, deltaTime: 1)

        #expect(scene.world.entity(for: first.id) == nil)
        #expect(scene.world.entity(for: second.id) == nil)
        #expect(scene.world.entity(for: third.id) == nil)
        #expect(scene.world.fireableComponents.entities.isEmpty)
        #expect(scene.world.motionComponents.entities == [scene.skiff.id])
    }

    @Test func lifetimeOnlyEntityCountsDownAndExpiresWithoutPhysicsOrDestructibility() {
        var world = World()
        let entity = LifetimeTestEntity(
            in: world,
            from: Entity.InitialState(lifetime: 2)
        )
        #expect(entity.remainingLifetime == 2)
        #expect(world.positionComponents[entity.id] == nil)
        #expect(world.motionComponents[entity.id] == nil)
        #expect(world.collisionBodyComponents[entity.id] == nil)
        #expect(world.destructibleComponents[entity.id] == nil)
        #expect(world.ownershipComponents[entity.id] == nil)
        #expect(world.fireableComponents[entity.id] == nil)

        var system = LifetimeSystem()
        system.update(world: &world, deltaTime: 0.5)

        #expect(world.entity(for: entity.id) === entity)
        #expect(entity.remainingLifetime == 1.5)

        system.update(world: &world, deltaTime: 1.5)

        #expect(world.entity(for: entity.id) == nil)
        #expect(world.lifetimeComponents[entity.id] == nil)
    }
}
