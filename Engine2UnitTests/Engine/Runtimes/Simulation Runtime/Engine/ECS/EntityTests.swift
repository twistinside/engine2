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
