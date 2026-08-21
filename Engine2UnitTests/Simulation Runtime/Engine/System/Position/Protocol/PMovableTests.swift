import Testing
@testable import Engine2

struct PMovableTests {
    @Test func motionReadsFromWorldStore() {
        let world = World()
        let entity = TestMovableEntity(
            unregisteredID: EntityID(index: 0, generation: 0),
            in: world
        )
        let expectedVelocity = SIMD3<Double>(1, 2, 3)
        let expectedAcceleration = SIMD3<Double>(4, 5, 6)
        let expectedImpulse = SIMD3<Double>(7, 8, 9)
        let expectedIntent = CMotion.AccelerationIntent.accelerating(
            SIMD3<Double>(10, 11, 12)
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
