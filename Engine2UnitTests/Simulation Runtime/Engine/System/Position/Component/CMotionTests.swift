import Testing
@testable import Engine2

struct CMotionTests {
    @Test func switchingAccelerationIntentToIdleClearsAccelerationOnly() async throws {
        let expectedVelocity = SIMD3<Float>(1, 2, 3)
        let accelerationIntentValue = SIMD3<Float>(7, 8, 9)
        let accelerationIntent = CMotion.AccelerationIntent.accelerating(
            accelerationIntentValue
        )
        let expectedImpulse = SIMD3<Float>(10, 11, 12)
        var motion = CMotion(
            velocity: expectedVelocity,
            accelerationIntent: accelerationIntent,
            impulse: expectedImpulse
        )
        let accumulatedAcceleration = SIMD3<Float>(4, 5, 6)
        motion.accumulator.acceleration = accumulatedAcceleration

        motion.accelerationIntent = .idle

        #expect(motion.accelerationIntent == .idle)
        #expect(motion.acceleration == .zero)
        #expect(motion.impulse == expectedImpulse)
        #expect(motion.velocity == expectedVelocity)
    }

    @Test func switchingAccelerationIntentToAcceleratingPreservesAccumulator() async throws {
        let expectedImpulse = SIMD3<Float>(4, 5, 6)
        var motion = CMotion(
            accelerationIntent: .idle,
            impulse: expectedImpulse
        )
        let expectedAcceleration = SIMD3<Float>(1, 2, 3)
        motion.accumulator.acceleration = expectedAcceleration

        let accelerationIntentValue = SIMD3<Float>(7, 8, 9)
        let expectedIntent = CMotion.AccelerationIntent.accelerating(
            accelerationIntentValue
        )
        motion.accelerationIntent = expectedIntent

        #expect(motion.accelerationIntent == expectedIntent)
        #expect(motion.acceleration == expectedAcceleration)
        #expect(motion.impulse == expectedImpulse)
    }
}
