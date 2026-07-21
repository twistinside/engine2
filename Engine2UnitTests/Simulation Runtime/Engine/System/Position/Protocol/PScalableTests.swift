import Testing
@testable import Engine2

struct PScalableTests {
    @Test func scaleReadsFromWorldStore() async throws {
        let world = World()
        let entity = TestScalableEntity(unregisteredID: EntityID(index: 0, generation: 0), in: world)
        let expectedScale = SIMD3<Float>(1.5, 2, 0.5)

        world.scaleComponents.insert(CScale(scale: expectedScale), for: entity.id)

        #expect(entity.scale == expectedScale)
    }
}

private final class TestScalableEntity: Entity, PScalable {}
