import Testing
@testable import Engine2

struct PPositionableTests {
    @Test func positionReadsFromWorldStore() {
        let world = World()
        let entity = TestPositionableEntity(
            unregisteredID: EntityID(index: 0, generation: 0),
            in: world
        )
        let expectedPosition = SIMD3<Float>(4, 5, 6)
        let position = CPosition(position: expectedPosition)

        world.positionComponents.insert(
            position,
            for: entity.id
        )

        #expect(entity.position == expectedPosition)
    }
}

private extension PPositionableTests {
    private final class TestPositionableEntity: Entity, PPositionable {}
}
