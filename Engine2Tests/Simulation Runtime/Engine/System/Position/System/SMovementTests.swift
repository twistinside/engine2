import Testing
@testable import Engine2

struct SMovementTests {
    @Test func integratesVelocityAndClearsAccumulator() async throws {
        var world = World()
        let entity = EntityID(index: 0, generation: 0)
        var motion = CMotion(
            velocity: SIMD3<Float>(4, 5, 6),
            impulse: SIMD3<Float>(1, -1, 0.5)
        )
        motion.accumulator.acceleration = SIMD3<Float>(2, 0, -2)

        world.positionComponents.insert(CPosition(position: SIMD3<Float>(1, 2, 3)), for: entity)
        world.motionComponents.insert(motion, for: entity)

        let system = SMovement()
        system.update(world: &world, deltaTime: 0.5)

        #expect(world.motionComponents[entity]?.velocity == SIMD3<Float>(6, 4, 5.5))
        #expect(world.positionComponents[entity]?.position == SIMD3<Float>(4, 4, 5.75))
        #expect(world.motionComponents[entity]?.acceleration == .zero)
        #expect(world.motionComponents[entity]?.impulse == .zero)
    }

    @Test func incompleteEntityWithoutPositionIsLeftUnchanged() {
        var world = World()
        let entity = EntityID(index: 0, generation: 0)
        var expectedMotion = CMotion(
            velocity: SIMD3<Float>(1, 2, 3),
            impulse: SIMD3<Float>(4, 5, 6)
        )
        expectedMotion.accumulator.acceleration = SIMD3<Float>(7, 8, 9)
        world.motionComponents.insert(expectedMotion, for: entity)

        SMovement().update(world: &world, deltaTime: 0.5)

        #expect(world.motionComponents[entity] == expectedMotion)
        #expect(world.positionComponents[entity] == nil)
    }
}
