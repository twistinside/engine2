import Testing
@testable import Engine2

struct EntityRemovalSystemTests {
    @Test func collectionRemovesAllMarkedRowsAndPreservesUnmarkedEntities() {
        var scene = MissileTestScene(velocity: .zero)
        let first = scene.missile(at: .zero, velocity: .zero, lifetime: 5)
        let survivor = scene.missile(at: .zero, velocity: .zero, lifetime: 5)
        let last = scene.missile(at: .zero, velocity: .zero, lifetime: 5)
        #expect(scene.world.markForRemoval(last.id))
        #expect(scene.world.markForRemoval(first.id))
        #expect(scene.world.fireableComponents.entities == [first.id, survivor.id, last.id])

        var removal = EntityRemovalSystem()
        removal.update(world: &scene.world, deltaTime: 1)
        removal.update(world: &scene.world, deltaTime: 1)

        #expect(scene.world.entity(for: first.id) == nil)
        #expect(scene.world.entity(for: last.id) == nil)
        #expect(scene.world.entity(for: survivor.id) === survivor)
        #expect(scene.world.fireableComponents.entities == [survivor.id])
        #expect(scene.world.lifetimeComponents.entities == [survivor.id])
        #expect(scene.world.ownershipComponents.entities == [survivor.id])
        #expect(scene.world.pendingRemovalComponents.entities.isEmpty)
        #expect(scene.world.motionComponents[survivor.id]?.velocity == .zero)
        #expect(scene.world.selectedEntityID == scene.skiff.id)
        #expect(scene.world.markForRemoval(first.id) == false)
    }

    @Test func markingRejectsUnregisteredAndDifferentGenerationalIdentities() {
        var world = World()
        let entity = Entity(in: world, from: .empty)
        let otherGeneration = EntityID(index: entity.id.index, generation: entity.id.generation + 1)
        let reserved = world.reserveEntityID()
        #expect(world.markForRemoval(otherGeneration) == false)
        #expect(world.markForRemoval(reserved) == false)

        var removal = EntityRemovalSystem()
        removal.update(world: &world, deltaTime: 1)

        #expect(world.entity(for: entity.id) === entity)
        #expect(world.registeredEntities.map(\.id) == [entity.id])
        #expect(world.pendingRemovalComponents.entities.isEmpty)
    }

    @Test func repeatedMarkingIsIdempotentAndDoesNotRequireDestructibility() {
        var world = World()
        let entity = Entity(in: world, from: .empty)
        #expect(world.markForRemoval(entity.id))
        #expect(world.markForRemoval(entity.id))
        #expect(world.pendingRemovalComponents.entities == [entity.id])
        #expect(world.entity(for: entity.id) === entity)
        #expect(world.destructibleComponents[entity.id] == nil)

        var removal = EntityRemovalSystem()
        removal.update(world: &world, deltaTime: 1)

        #expect(world.entity(for: entity.id) == nil)
        #expect(world.pendingRemovalComponents.entities.isEmpty)
    }

    @Test func immediateDestructionClearsItsPendingMarkerBeforeCollection() {
        var world = World()
        let entity = Entity(in: world, from: .empty)
        #expect(world.markForRemoval(entity.id))

        #expect(world.destroy(entity.id))

        #expect(world.entity(for: entity.id) == nil)
        #expect(world.pendingRemovalComponents.entities.isEmpty)
        var removal = EntityRemovalSystem()
        removal.update(world: &world, deltaTime: 1)
        #expect(world.registeredEntities.isEmpty)
        #expect(world.pendingRemovalComponents.entities.isEmpty)
    }

    @Test func collectionClearsContactFactsAfterResponse() {
        var scene = MissileTestScene(velocity: .zero)
        let target = scene.asteroid(at: SIMD3<Double>(60, 0, 0), velocity: .zero)
        let missile = scene.missile(at: SIMD3<Double>(10, 0, 0), velocity: SIMD3<Double>(100, 0, 0), lifetime: 5)
        scene.move(deltaTime: 1)
        var detector = FireableCollisionSystem()
        detector.update(world: &scene.world, deltaTime: 1)
        var response = FireableImpactSystem()
        response.update(world: &scene.world, deltaTime: 1)
        #expect(scene.world.fireableCollisions.count == 1)

        var removal = EntityRemovalSystem()
        removal.update(world: &scene.world, deltaTime: 1)

        #expect(scene.world.fireableCollisions.isEmpty)
        #expect(scene.world.pendingRemovalComponents.entities.isEmpty)
        #expect(scene.world.entity(for: target.id) == nil)
        #expect(scene.world.entity(for: missile.id) == nil)
    }
}
