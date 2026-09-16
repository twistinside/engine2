import Testing
@testable import Engine2

struct EntityTests {
    @Test func unregisteredInitializerCreatesOnlyALiveFacade() {
        let world = World()
        let id = EntityID(index: 99, generation: 7)
        let entity = Entity(unregisteredID: id, in: world)

        #expect(entity.id == id)
        #expect(entity.world === world)
        #expect(entity.lifecycleState == nil)
        #expect(world.lifecycleComponents[id] == nil)
        #expect(capabilityComponentRowCounts(in: world).allSatisfy { $0 == 0 })
    }

    @Test func baseEntityRegistrationCreatesOneActiveLifecycleRowPerIdentity() {
        let world = World()
        let first = Entity(in: world, from: .empty)
        let second = Entity(in: world, from: .empty)

        #expect(first.id == EntityID(index: 0, generation: 0))
        #expect(second.id == EntityID(index: 1, generation: 0))
        #expect(first.lifecycleState == .active)
        #expect(second.lifecycleState == .active)
        #expect(world.lifecycleComponents.entities == [first.id, second.id])
        #expect(world.lifecycleComponents.dense.allSatisfy { $0.state == .active })
        #expect(capabilityComponentRowCounts(in: world).allSatisfy { $0 == 0 })
    }

    @Test func repeatedComponentMarkingIsIdempotentAndVisibleThroughTheLiveFacade() {
        let world = World()
        let entity = Entity(in: world, from: .empty)

        #expect(world.lifecycleComponents.update(for: entity.id) { $0.state = .pendingRemoval })
        #expect(world.lifecycleComponents.update(for: entity.id) { $0.state = .pendingRemoval })

        #expect(entity.lifecycleState == .pendingRemoval)
        #expect(world.lifecycleComponents.entities == [entity.id])
        #expect(world.entity(for: entity.id) === entity)
        #expect(world.lifetimeComponents[entity.id] == nil)
        #expect(capabilityComponentRowCounts(in: world).allSatisfy { $0 == 0 })
    }

    @Test func reseedingComponentsPreservesPendingRemoval() {
        let world = World()
        let entity = LifetimeTestEntity(in: world, from: Entity.InitialState(lifetime: 2))
        #expect(world.lifecycleComponents.update(for: entity.id) { $0.state = .pendingRemoval })

        world.add(entity, from: Entity.InitialState(lifetime: 5))

        #expect(entity.lifecycleState == .pendingRemoval)
        #expect(world.lifecycleComponents[entity.id]?.state == .pendingRemoval)
        #expect(world.lifecycleComponents.entities == [entity.id])
        #expect(entity.remainingLifetime == 5)
        #expect(world.entity(for: entity.id) === entity)
        #expect(world.registeredEntities.map(\.id) == [entity.id])
    }

    @Test func unregisteredAliasDoesNotExposeTheLiveIdentityLifecycle() {
        let world = World()
        let entity = Entity(in: world, from: .empty)
        let alias = Entity(unregisteredID: entity.id, in: world)

        #expect(alias.lifecycleState == nil)
        #expect(entity.lifecycleState == .active)
        #expect(world.entity(for: entity.id) === entity)
        #expect(world.registeredEntities.map(\.id) == [entity.id])

        #expect(world.lifecycleComponents.update(for: entity.id) { $0.state = .pendingRemoval })

        #expect(entity.lifecycleState == .pendingRemoval)
        #expect(alias.lifecycleState == nil)
    }

    @Test func componentUpdateRejectsADifferentGenerationAtTheLiveIndex() {
        let world = World()
        let entity = Entity(in: world, from: .empty)
        let otherGeneration = EntityID(index: entity.id.index, generation: entity.id.generation + 1)
        let alias = Entity(unregisteredID: otherGeneration, in: world)

        #expect(world.lifecycleComponents.update(for: otherGeneration) { $0.state = .pendingRemoval } == false)
        #expect(world.destroy(otherGeneration) == false)

        #expect(alias.lifecycleState == nil)
        #expect(entity.lifecycleState == .active)
        #expect(world.lifecycleComponents[otherGeneration] == nil)
        #expect(world.lifecycleComponents[entity.id]?.state == .active)
        #expect(world.entity(for: entity.id) === entity)
        #expect(world.entity(for: otherGeneration) == nil)
        #expect(world.registeredEntities.map(\.id) == [entity.id])
    }

    @Test func reservedFacadeBecomesActiveOnlyAfterRegistration() {
        let world = World()
        let entity = Entity(unregisteredID: world.reserveEntityID(), in: world)

        #expect(world.lifecycleComponents.update(for: entity.id) { $0.state = .pendingRemoval } == false)
        #expect(entity.lifecycleState == nil)
        #expect(world.lifecycleComponents[entity.id] == nil)
        #expect(world.entity(for: entity.id) == nil)
        #expect(world.registeredEntities.isEmpty)

        world.add(entity)

        #expect(entity.lifecycleState == .active)
        #expect(world.lifecycleComponents[entity.id]?.state == .active)
        #expect(world.entity(for: entity.id) === entity)
    }

    @Test(arguments: [false, true])
    func removedFacadeHasNoLifecycleRow(wasMarked: Bool) {
        let world = World()
        let entity = Entity(in: world, from: .empty)
        if wasMarked {
            #expect(world.lifecycleComponents.update(for: entity.id) { $0.state = .pendingRemoval })
        }
        #expect(world.destroy(entity.id))

        #expect(world.lifecycleComponents.update(for: entity.id) { $0.state = .pendingRemoval } == false)
        #expect(world.destroy(entity.id) == false)

        #expect(entity.lifecycleState == nil)
        #expect(world.lifecycleComponents[entity.id] == nil)
        #expect(world.lifecycleComponents.entities.isEmpty)
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

    private func capabilityComponentRowCounts(in world: World) -> [Int] {
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
