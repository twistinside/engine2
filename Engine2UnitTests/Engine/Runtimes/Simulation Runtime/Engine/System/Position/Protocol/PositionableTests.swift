import Testing
@testable import Engine2

struct PositionableTests {
    @Test func positionReadsFromWorldStore() {
        let world = World()
        let entity = TestPositionableEntity(
            unregisteredID: EntityID(index: 0, generation: 0),
            in: world
        )
        let expectedPosition = SIMD3<Double>(4, 5, 6)
        let position = PositionComponent(position: expectedPosition)

        world.positionComponents.insert(
            position,
            for: entity.id
        )

        #expect(entity.position == expectedPosition)
    }
}

private extension PositionableTests {
    private final class TestPositionableEntity: Entity, Positionable {}
}
