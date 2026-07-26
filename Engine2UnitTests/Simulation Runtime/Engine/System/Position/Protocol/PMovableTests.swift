import Testing
@testable import Engine2

struct PMovableTests {
    @Test func motionReadsFromWorldStore() {
        let world = World()
        let entityID = EntityID(index: 0, generation: 0)
        let entity = TestMovableEntity(
            unregisteredID: entityID,
            in: world
        )
        let expectedVelocity = SIMD3<Float>(1, 2, 3)
        let expectedAcceleration = SIMD3<Float>(4, 5, 6)
        let expectedImpulse = SIMD3<Float>(7, 8, 9)
        let accelerationIntentValue = SIMD3<Float>(10, 11, 12)
        let expectedIntent = CMotion.AccelerationIntent.accelerating(
            accelerationIntentValue
        )
        var motion = CMotion(
            velocity: expectedVelocity,
            accelerationIntent: expectedIntent,
            impulse: expectedImpulse
        )
        motion.accumulator.acceleration = expectedAcceleration

        world.motionComponents.insert(motion, for: entity.id)

        #expect(entity.velocity == expectedVelocity)
        #expect(entity.acceleration == expectedAcceleration)
        #expect(entity.impulse == expectedImpulse)
        #expect(entity.accelerationIntent == expectedIntent)
    }
}

private extension PMovableTests {
    private final class TestMovableEntity: Entity, PMovable {}
}
