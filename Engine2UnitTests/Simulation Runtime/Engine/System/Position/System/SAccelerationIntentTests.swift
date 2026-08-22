import Testing
@testable import Engine2

struct SAccelerationIntentTests {
    @Test func acceleratingIntentEmitsAccelerationEveryStep() async throws {
        var world = World()
        let entity = EntityID(index: 0, generation: 0)

        let position = CPosition(position: .zero)
        world.positionComponents.insert(position, for: entity)
        let accelerationIntent = CMotion.AccelerationIntent.accelerating(
            SIMD3<Double>(2, 0, 0)
        )
        let motion = CMotion(
            velocity: .zero,
            accelerationIntent: accelerationIntent,
            impulse: .zero
        )
        world.motionComponents.insert(
            motion,
            for: entity
        )

        var intentSystem = SAccelerationIntent()
        var movementSystem = SMovement()

        intentSystem.update(world: &world, deltaTime: 0.5)
        movementSystem.update(world: &world, deltaTime: 0.5)

        #expect(world.motionComponents[entity]?.velocity == SIMD3<Double>(1, 0, 0))
        #expect(world.positionComponents[entity]?.position == SIMD3<Double>(0.5, 0, 0))
        #expect(world.motionComponents[entity]?.acceleration == .zero)
        #expect(world.motionComponents[entity]?.accelerationIntent == accelerationIntent)

        intentSystem.update(world: &world, deltaTime: 0.5)
        movementSystem.update(world: &world, deltaTime: 0.5)

        #expect(world.motionComponents[entity]?.velocity == SIMD3<Double>(2, 0, 0))
        #expect(world.positionComponents[entity]?.position == SIMD3<Double>(1.5, 0, 0))
        #expect(world.motionComponents[entity]?.acceleration == .zero)
    }

    @Test func idleIntentDoesNotEmitAcceleration() async throws {
        var world = World()
        let entity = EntityID(index: 0, generation: 0)
        let motion = CMotion.motionless

        world.motionComponents.insert(
            motion,
            for: entity
        )

        var system = SAccelerationIntent()
        system.update(world: &world, deltaTime: 1)

        #expect(world.motionComponents[entity]?.acceleration == .zero)
        #expect(world.motionComponents[entity]?.accelerationIntent == .idle)
    }
}
