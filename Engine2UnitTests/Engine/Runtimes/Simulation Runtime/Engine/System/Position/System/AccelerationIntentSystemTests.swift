import Testing
@testable import Engine2

struct AccelerationIntentSystemTests {
    @Test func acceleratingIntentEmitsAccelerationEveryStep() async throws {
        var world = World()
        let entity = EntityID(index: 0, generation: 0)

        let position = PositionComponent(position: .zero)
        world.components[PositionComponent.self].insert(position, for: entity)
        let accelerationIntent = MotionComponent.AccelerationIntent.accelerating(
            SIMD3<Double>(2, 0, 0)
        )
        let motion = MotionComponent(
            velocity: .zero,
            accelerationIntent: accelerationIntent
        )
        world.components[MotionComponent.self].insert(
            motion,
            for: entity
        )

        var intentSystem = AccelerationIntentSystem()
        var movementSystem = MovementSystem()

        intentSystem.update(world: &world, deltaTime: 0.5)
        movementSystem.update(world: &world, deltaTime: 0.5)

        #expect(world.components[MotionComponent.self][entity]?.velocity == SIMD3<Double>(1, 0, 0))
        #expect(world.components[PositionComponent.self][entity]?.position == SIMD3<Double>(0.5, 0, 0))
        #expect(world.components[MotionComponent.self][entity]?.acceleration == .zero)
        #expect(world.components[MotionComponent.self][entity]?.accelerationIntent == accelerationIntent)

        intentSystem.update(world: &world, deltaTime: 0.5)
        movementSystem.update(world: &world, deltaTime: 0.5)

        #expect(world.components[MotionComponent.self][entity]?.velocity == SIMD3<Double>(2, 0, 0))
        #expect(world.components[PositionComponent.self][entity]?.position == SIMD3<Double>(1.5, 0, 0))
        #expect(world.components[MotionComponent.self][entity]?.acceleration == .zero)
    }

    @Test func idleIntentDoesNotEmitAcceleration() async throws {
        var world = World()
        let entity = EntityID(index: 0, generation: 0)
        let motion = MotionComponent(accelerationIntent: .idle)

        world.components[MotionComponent.self].insert(
            motion,
            for: entity
        )

        var system = AccelerationIntentSystem()
        system.update(world: &world, deltaTime: 1)

        #expect(world.components[MotionComponent.self][entity]?.acceleration == .zero)
        #expect(world.components[MotionComponent.self][entity]?.accelerationIntent == .idle)
    }
}
