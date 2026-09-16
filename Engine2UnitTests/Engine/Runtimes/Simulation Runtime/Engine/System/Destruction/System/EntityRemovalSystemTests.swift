import Testing
@testable import Engine2

struct EntityRemovalSystemTests {
    @Test func collectionRemovesAllMarkedRowsAndPreservesUnmarkedEntities() {
        var scene = MissileTestScene(velocity: .zero)
        let first = scene.missile(at: .zero, velocity: .zero, lifetime: 5)
        let survivor = scene.missile(at: .zero, velocity: .zero, lifetime: 5)
        let last = scene.missile(at: .zero, velocity: .zero, lifetime: 5)
        #expect(scene.world.lifecycleComponents.update(for: last.id) { $0.state = .pendingRemoval })
        #expect(scene.world.lifecycleComponents.update(for: first.id) { $0.state = .pendingRemoval })
        #expect(scene.world.contactConsumptionComponents.entities == [first.id, survivor.id, last.id])

        var removal = EntityRemovalSystem()
        removal.update(world: &scene.world, deltaTime: 1)
        removal.update(world: &scene.world, deltaTime: 1)

        #expect(scene.world.entity(for: first.id) == nil)
        #expect(scene.world.entity(for: last.id) == nil)
        #expect(scene.world.entity(for: survivor.id) === survivor)
        #expect(scene.world.lifecycleComponents[first.id] == nil)
        #expect(scene.world.lifecycleComponents[last.id] == nil)
        #expect(scene.world.lifecycleComponents[survivor.id]?.state == .active)
        #expect(Set(scene.world.lifecycleComponents.entities) == Set(scene.world.registeredEntities.map(\.id)))
        #expect(scene.world.contactConsumptionComponents.entities == [survivor.id])
        #expect(scene.world.lifetimeComponents.entities == [survivor.id])
        #expect(scene.world.ownershipComponents.entities == [survivor.id])
        #expect(first.lifecycleState == nil)
        #expect(last.lifecycleState == nil)
        #expect(survivor.lifecycleState == .active)
        #expect(scene.world.motionComponents[survivor.id]?.velocity == .zero)
        #expect(scene.world.selectedEntityID == scene.skiff.id)
    }

    @Test func collectionUsesTheLifecycleComponentForPlainEntities() {
        var world = World()
        let removed = Entity(in: world, from: .empty)
        let survivor = Entity(in: world, from: .empty)
        #expect(world.lifecycleComponents.update(for: removed.id) { $0.state = .pendingRemoval })

        var removal = EntityRemovalSystem()
        removal.update(world: &world, deltaTime: 1)

        #expect(removed.lifecycleState == nil)
        #expect(survivor.lifecycleState == .active)
        #expect(world.entity(for: removed.id) == nil)
        #expect(world.entity(for: survivor.id) === survivor)
        #expect(world.registeredEntities.map(\.id) == [survivor.id])
        #expect(world.lifecycleComponents.entities == [survivor.id])
        #expect(world.lifecycleComponents[removed.id] == nil)
        #expect(world.lifecycleComponents[survivor.id]?.state == .active)
    }

    @Test func immediateDestructionRemovesTheLifecycleRowBeforeCollection() {
        var world = World()
        let entity = Entity(in: world, from: .empty)
        #expect(world.lifecycleComponents.update(for: entity.id) { $0.state = .pendingRemoval })

        #expect(world.destroy(entity.id))

        #expect(world.entity(for: entity.id) == nil)
        #expect(entity.lifecycleState == nil)
        var removal = EntityRemovalSystem()
        removal.update(world: &world, deltaTime: 1)
        #expect(world.registeredEntities.isEmpty)
        #expect(world.lifecycleComponents.entities.isEmpty)
        #expect(entity.lifecycleState == nil)
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
        #expect(target.lifecycleState == nil)
        #expect(missile.lifecycleState == nil)
        #expect(scene.world.entity(for: target.id) == nil)
        #expect(scene.world.entity(for: missile.id) == nil)
    }
}
