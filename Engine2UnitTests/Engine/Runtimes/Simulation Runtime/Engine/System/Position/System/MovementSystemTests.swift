import Testing
@testable import Engine2

struct MovementSystemTests {
    @Test func integratesVelocityAndClearsAccumulator() async throws {
        var world = World()
        let entity = EntityID(index: 0, generation: 0)
        var motion = MotionComponent(
            velocity: SIMD3<Double>(4, 5, 6),
            impulse: SIMD3<Double>(1, -1, 0.5)
        )
        motion.accumulator.acceleration = SIMD3<Double>(2, 0, -2)

        let initialPosition = PositionComponent(position: SIMD3<Double>(1, 2, 3))
        world.components[PositionComponent.self].insert(initialPosition, for: entity)
        world.components[MotionComponent.self].insert(motion, for: entity)

        var system = MovementSystem()
        system.update(world: &world, deltaTime: 0.5)

        #expect(
            world.components[MotionComponent.self][entity]?.velocity == SIMD3<Double>(6, 4, 5.5)
        )
        #expect(
            world.components[PositionComponent.self][entity]?.position == SIMD3<Double>(4, 4, 5.75)
        )
        #expect(world.components[MotionComponent.self][entity]?.acceleration == .zero)
        #expect(world.components[MotionComponent.self][entity]?.impulse == .zero)
    }

    @Test func incompleteEntityWithoutPositionIsLeftUnchanged() {
        var world = World()
        let entity = EntityID(index: 0, generation: 0)
        var expectedMotion = MotionComponent(
            velocity: SIMD3<Double>(1, 2, 3),
            impulse: SIMD3<Double>(4, 5, 6)
        )
        expectedMotion.accumulator.acceleration = SIMD3<Double>(7, 8, 9)
        world.components[MotionComponent.self].insert(expectedMotion, for: entity)

        var system = MovementSystem()
        system.update(world: &world, deltaTime: 0.5)

        #expect(world.components[MotionComponent.self][entity] == expectedMotion)
        #expect(world.components[PositionComponent.self][entity] == nil)
    }
}
