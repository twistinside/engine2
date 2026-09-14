import Testing
@testable import Engine2

struct EntityTests {
    @Test func unregisteredInitializerCreatesOnlyALiveFacade() {
        let world = World()
        let id = EntityID(index: 99, generation: 7)
        let entity = Entity(unregisteredID: id, in: world)

        #expect(entity.id == id)
        #expect(entity.world === world)
        #expect(entity.lifecycleState == .unregistered)
        #expect(componentRowCounts(in: world).allSatisfy { $0 == 0 })
    }

    @Test func baseEntityRegistrationConsumesIdentityWithoutInventingCapabilities() {
        let world = World()
        let first = Entity(in: world, from: .empty)
        let second = Entity(in: world, from: .empty)

        #expect(first.id == EntityID(index: 0, generation: 0))
        #expect(second.id == EntityID(index: 1, generation: 0))
        #expect(first.lifecycleState == .active)
        #expect(second.lifecycleState == .active)
        #expect(componentRowCounts(in: world).allSatisfy { $0 == 0 })
    }

    @Test func markingPlainEntityIsIdempotentAndRetainsItsLiveFacade() {
        let world = World()
        let entity = Entity(in: world, from: .empty)

        #expect(entity.markForRemoval())
        #expect(entity.markForRemoval())

        #expect(entity.lifecycleState == .pendingRemoval)
        #expect(world.entity(for: entity.id) === entity)
        #expect(world.destructibleComponents[entity.id] == nil)
        #expect(world.lifetimeComponents[entity.id] == nil)
        #expect(componentRowCounts(in: world).allSatisfy { $0 == 0 })
    }

    @Test func reseedingComponentsPreservesPendingRemoval() {
        let world = World()
        let entity = LifetimeTestEntity(in: world, from: Entity.InitialState(lifetime: 2))
        #expect(entity.markForRemoval())

        world.add(entity, from: Entity.InitialState(lifetime: 5))

        #expect(entity.lifecycleState == .pendingRemoval)
        #expect(entity.remainingLifetime == 5)
        #expect(world.entity(for: entity.id) === entity)
        #expect(world.registeredEntities.map(\.id) == [entity.id])
    }

    @Test func markingRejectsAnUnregisteredAliasWithTheLiveIdentity() {
        let world = World()
        let entity = Entity(in: world, from: .empty)
        let alias = Entity(unregisteredID: entity.id, in: world)

        #expect(alias.markForRemoval() == false)

        #expect(alias.lifecycleState == .unregistered)
        #expect(entity.lifecycleState == .active)
        #expect(world.entity(for: entity.id) === entity)
        #expect(world.registeredEntities.map(\.id) == [entity.id])
        #expect(entity.markForRemoval())
        #expect(entity.lifecycleState == .pendingRemoval)
        #expect(alias.lifecycleState == .unregistered)
    }

    @Test func markingRejectsADifferentGenerationAtTheLiveIndex() {
        let world = World()
        let entity = Entity(in: world, from: .empty)
        let otherGeneration = EntityID(index: entity.id.index, generation: entity.id.generation + 1)
        let alias = Entity(unregisteredID: otherGeneration, in: world)

        #expect(alias.markForRemoval() == false)
        #expect(world.destroy(otherGeneration) == false)

        #expect(alias.lifecycleState == .unregistered)
        #expect(entity.lifecycleState == .active)
        #expect(world.entity(for: entity.id) === entity)
        #expect(world.entity(for: otherGeneration) == nil)
        #expect(world.registeredEntities.map(\.id) == [entity.id])
    }

    @Test func reservedFacadeBecomesActiveOnlyAfterRegistration() {
        let world = World()
        let entity = Entity(unregisteredID: world.reserveEntityID(), in: world)

        #expect(entity.markForRemoval() == false)
        #expect(entity.lifecycleState == .unregistered)
        #expect(world.entity(for: entity.id) == nil)
        #expect(world.registeredEntities.isEmpty)

        world.add(entity)

        #expect(entity.lifecycleState == .active)
        #expect(world.entity(for: entity.id) === entity)
    }

    @Test(arguments: [false, true])
    func retainedFacadeCannotMarkItselfAfterDestruction(wasMarked: Bool) {
        let world = World()
        let entity = Entity(in: world, from: .empty)
        if wasMarked {
            #expect(entity.markForRemoval())
        }
        #expect(world.destroy(entity.id))

        #expect(entity.markForRemoval() == false)
        #expect(world.destroy(entity.id) == false)

        #expect(entity.lifecycleState == .removed)
        #expect(world.entity(for: entity.id) == nil)
        #expect(world.registeredEntities.isEmpty)
    }

    @Test func removedFacadeCannotBeRegisteredAgain() async {
        await #expect(processExitsWith: .failure) {
            await MainActor.run {
                let world = World()
                let entity = Entity(in: world, from: .empty)
                world.destroy(entity.id)

                world.add(entity)
            }
        }
    }

    @Test func registrationRejectsAnAliasOfTheLiveFacade() async {
        await #expect(processExitsWith: .failure) {
            await MainActor.run {
                let world = World()
                let entity = Entity(in: world, from: .empty)
                let alias = Entity(unregisteredID: entity.id, in: world)

                world.add(alias)
            }
        }
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
