import Testing
import simd
@testable import Engine2

struct POrientableTests {
    @Test func rotationReadsFromWorldStore() async throws {
        let world = World()
        let entity = TestRotatableEntity(
            unregisteredID: EntityID(index: 0, generation: 0),
            in: world
        )
        let expectedRotation = simd_quatf(angle: .pi / 4, axis: SIMD3<Float>(0, 1, 0))
        let rotation = CRotation(rotation: expectedRotation)

        world.rotationComponents.insert(rotation, for: entity.id)

        #expect(entity.rotation.vector == expectedRotation.vector)
    }
}

private extension POrientableTests {
    private final class TestRotatableEntity: Entity, POrientable {}
}
