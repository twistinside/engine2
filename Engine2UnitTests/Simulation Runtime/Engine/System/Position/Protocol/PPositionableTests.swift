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

        world.positionComponents.insert(
            CPosition(position: expectedPosition),
            for: entity.id
        )

        #expect(entity.position == expectedPosition)
    }
}

private final class TestPositionableEntity: Entity, PPositionable {}
