import Testing
@testable import Engine2

struct EntityRemovalSystemTests {
    @Test func collectionRemovesAllMarkedRowsAndPreservesUnmarkedEntities() {
        var scene = MissileTestScene(velocity: .zero)
        let first = scene.missile(at: .zero, velocity: .zero, lifetime: 5)
        let survivor = scene.missile(at: .zero, velocity: .zero, lifetime: 5)
        let last = scene.missile(at: .zero, velocity: .zero, lifetime: 5)
        #expect(last.markForRemoval())
        #expect(first.markForRemoval())
        #expect(scene.world.contactConsumptionComponents.entities == [first.id, survivor.id, last.id])

        var removal = EntityRemovalSystem()
        removal.update(world: &scene.world, deltaTime: 1)
        removal.update(world: &scene.world, deltaTime: 1)

        #expect(scene.world.entity(for: first.id) == nil)
        #expect(scene.world.entity(for: last.id) == nil)
        #expect(scene.world.entity(for: survivor.id) === survivor)
        #expect(scene.world.contactConsumptionComponents.entities == [survivor.id])
        #expect(scene.world.lifetimeComponents.entities == [survivor.id])
        #expect(scene.world.ownershipComponents.entities == [survivor.id])
        #expect(first.lifecycleState == .removed)
        #expect(last.lifecycleState == .removed)
        #expect(survivor.lifecycleState == .active)
        #expect(scene.world.motionComponents[survivor.id]?.velocity == .zero)
        #expect(scene.world.selectedEntityID == scene.skiff.id)
    }

    @Test func collectionUsesEntityLifecycleWithoutAnyComponentRows() {
        var world = World()
        let removed = Entity(in: world, from: .empty)
        let survivor = Entity(in: world, from: .empty)
        #expect(removed.markForRemoval())

        var removal = EntityRemovalSystem()
        removal.update(world: &world, deltaTime: 1)

        #expect(removed.lifecycleState == .removed)
        #expect(survivor.lifecycleState == .active)
        #expect(world.entity(for: removed.id) == nil)
        #expect(world.entity(for: survivor.id) === survivor)
        #expect(world.registeredEntities.map(\.id) == [survivor.id])
    }

    @Test func immediateDestructionCompletesLifecycleBeforeCollection() {
        var world = World()
        let entity = Entity(in: world, from: .empty)
        #expect(entity.markForRemoval())

        #expect(world.destroy(entity.id))

        #expect(world.entity(for: entity.id) == nil)
        #expect(entity.lifecycleState == .removed)
        var removal = EntityRemovalSystem()
        removal.update(world: &world, deltaTime: 1)
        #expect(world.registeredEntities.isEmpty)
        #expect(entity.lifecycleState == .removed)
    }

    @Test func collectionClearsContactFactsAfterResponse() {
        var scene = MissileTestScene(velocity: .zero)
        let target = scene.asteroid(at: SIMD3<Double>(60, 0, 0), velocity: .zero)
        let missile = scene.missile(at: SIMD3<Double>(10, 0, 0), velocity: SIMD3<Double>(100, 0, 0), lifetime: 5)
        scene.move(deltaTime: 1)
        var detector = CollisionSystem()
        detector.update(world: &scene.world, deltaTime: 1)
        var response = ContactEffectSystem()
        response.update(world: &scene.world, deltaTime: 1)
        #expect(scene.world.collisionContacts.count == 1)
        #expect(scene.world.collisionSweeps.isEmpty == false)

        var removal = EntityRemovalSystem()
        removal.update(world: &scene.world, deltaTime: 1)

        #expect(scene.world.collisionContacts.isEmpty)
        #expect(scene.world.collisionSweeps.isEmpty)
        #expect(target.lifecycleState == .removed)
        #expect(missile.lifecycleState == .removed)
        #expect(scene.world.entity(for: target.id) == nil)
        #expect(scene.world.entity(for: missile.id) == nil)
    }
}
