import Testing
@testable import Engine2

struct EntityTests {
    @Test func unregisteredInitializerCreatesOnlyALiveFacade() {
        let world = World()
        let id = EntityID(index: 99, generation: 7)
        let entity = Entity(unregisteredID: id, in: world)

        #expect(entity.id == id)
        #expect(entity.world === world)
        #expect(componentRowCounts(in: world).allSatisfy { $0 == 0 })
    }

    @Test func baseEntityRegistrationConsumesIdentityWithoutInventingCapabilities() {
        let world = World()
        let first = Entity(in: world, from: .empty)
        let second = Entity(in: world, from: .empty)

        #expect(first.id == EntityID(index: 0, generation: 0))
        #expect(second.id == EntityID(index: 1, generation: 0))
        #expect(componentRowCounts(in: world).allSatisfy { $0 == 0 })
    }

    @Test func markingPlainEntityIsIdempotentAndRetainsItsLiveFacade() {
        let world = World()
        let entity = Entity(in: world, from: .empty)

        #expect(entity.markForRemoval())
        #expect(entity.markForRemoval())

        #expect(world.pendingRemovalComponents.entities == [entity.id])
        #expect(world.entity(for: entity.id) === entity)
        #expect(world.destructibleComponents[entity.id] == nil)
        #expect(world.lifetimeComponents[entity.id] == nil)
        #expect(componentRowCounts(in: world).allSatisfy { $0 == 0 })
    }

    @Test func markingUsesTheComponentStoreAsItsSourceOfTruth() {
        let world = World()
        let entity = Entity(in: world, from: .empty)
        #expect(entity.markForRemoval())
        let removedMarker = world.pendingRemovalComponents.remove(for: entity.id)
        #expect(removedMarker)

        #expect(entity.markForRemoval())

        #expect(world.pendingRemovalComponents.entities == [entity.id])
        #expect(world.entity(for: entity.id) === entity)
    }

    @Test func markingRejectsAnUnregisteredAliasWithTheLiveIdentity() {
        let world = World()
        let entity = Entity(in: world, from: .empty)
        let alias = Entity(unregisteredID: entity.id, in: world)

        #expect(alias.markForRemoval() == false)

        #expect(world.pendingRemovalComponents.entities.isEmpty)
        #expect(world.entity(for: entity.id) === entity)
        #expect(world.registeredEntities.map(\.id) == [entity.id])
        #expect(entity.markForRemoval())
        #expect(world.pendingRemovalComponents.entities == [entity.id])
    }

    @Test func markingRejectsADifferentGenerationAtTheLiveIndex() {
        let world = World()
        let entity = Entity(in: world, from: .empty)
        let otherGeneration = EntityID(index: entity.id.index, generation: entity.id.generation + 1)
        let alias = Entity(unregisteredID: otherGeneration, in: world)

        #expect(alias.markForRemoval() == false)

        #expect(world.pendingRemovalComponents.entities.isEmpty)
        #expect(world.entity(for: entity.id) === entity)
        #expect(world.entity(for: otherGeneration) == nil)
        #expect(world.registeredEntities.map(\.id) == [entity.id])
    }

    @Test func markingRejectsAReservedButUnregisteredFacade() {
        let world = World()
        let entity = Entity(unregisteredID: world.reserveEntityID(), in: world)

        #expect(entity.markForRemoval() == false)

        #expect(world.pendingRemovalComponents.entities.isEmpty)
        #expect(world.entity(for: entity.id) == nil)
        #expect(world.registeredEntities.isEmpty)
    }

    @Test func retainedFacadeCannotMarkItselfAfterDestruction() {
        let world = World()
        let entity = Entity(in: world, from: .empty)
        #expect(entity.markForRemoval())
        #expect(world.destroy(entity.id))

        #expect(entity.markForRemoval() == false)

        #expect(world.pendingRemovalComponents.entities.isEmpty)
        #expect(world.entity(for: entity.id) == nil)
        #expect(world.registeredEntities.isEmpty)
    }

    private func componentRowCounts(in world: World) -> [Int] {
        [
            world.angularMotionAccumulatorComponents.dense.count,
            world.angularVelocityComponents.dense.count,
            world.motionComponents.dense.count,
            world.positionComponents.dense.count,
            world.renderableComponents.dense.count,
            world.rotationComponents.dense.count,
            world.scaleComponents.dense.count,
            world.selectableComponents.dense.count
        ]
    }
}
