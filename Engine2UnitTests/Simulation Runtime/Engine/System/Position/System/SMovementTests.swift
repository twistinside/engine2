import Testing
@testable import Engine2

struct SMovementTests {
    @Test func integratesVelocityAndClearsAccumulator() async throws {
        var world = World()
        let entity = EntityID(index: 0, generation: 0)
        let initialVelocity = SIMD3<Float>(4, 5, 6)
        let initialImpulse = SIMD3<Float>(1, -1, 0.5)
        var motion = CMotion(
            velocity: initialVelocity,
            impulse: initialImpulse
        )
        motion.accumulator.acceleration = SIMD3<Float>(2, 0, -2)

        let initialPositionValue = SIMD3<Float>(1, 2, 3)
        let initialPosition = CPosition(position: initialPositionValue)
        world.positionComponents.insert(initialPosition, for: entity)
        world.motionComponents.insert(motion, for: entity)

        var system = SMovement()
        system.update(world: &world, deltaTime: 0.5)

        let expectedVelocity = SIMD3<Float>(6, 4, 5.5)
        let expectedPosition = SIMD3<Float>(4, 4, 5.75)

        #expect(world.motionComponents[entity]?.velocity == expectedVelocity)
        #expect(world.positionComponents[entity]?.position == expectedPosition)
        #expect(world.motionComponents[entity]?.acceleration == .zero)
        #expect(world.motionComponents[entity]?.impulse == .zero)
    }

    @Test func incompleteEntityWithoutPositionIsLeftUnchanged() {
        var world = World()
        let entity = EntityID(index: 0, generation: 0)
        let expectedVelocity = SIMD3<Float>(1, 2, 3)
        let expectedImpulse = SIMD3<Float>(4, 5, 6)
        var expectedMotion = CMotion(
            velocity: expectedVelocity,
            impulse: expectedImpulse
        )
        expectedMotion.accumulator.acceleration = SIMD3<Float>(7, 8, 9)
        world.motionComponents.insert(expectedMotion, for: entity)

        var system = SMovement()
        system.update(world: &world, deltaTime: 0.5)

        #expect(world.motionComponents[entity] == expectedMotion)
        #expect(world.positionComponents[entity] == nil)
    }
}
