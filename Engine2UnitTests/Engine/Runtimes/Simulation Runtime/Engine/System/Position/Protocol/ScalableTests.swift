import Testing
@testable import Engine2

struct ScalableTests {
    @Test func scaleReadsFromWorldStore() async throws {
        let world = World()
        let entity = TestScalableEntity(
            unregisteredID: EntityID(index: 0, generation: 0),
            in: world
        )
        let expectedScale = SIMD3<Float>(1.5, 2, 0.5)
        let scale = ScaleComponent(scale: expectedScale)

        world.components[ScaleComponent.self].insert(scale, for: entity.id)

        #expect(entity.scale == expectedScale)
    }
}

private extension ScalableTests {
    private final class TestScalableEntity: Entity, Scalable {}
}
