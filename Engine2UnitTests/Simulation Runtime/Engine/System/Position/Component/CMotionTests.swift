import Testing
@testable import Engine2

struct CMotionTests {
    @Test func motionlessHasNoMovementOrPendingContributions() {
        let motion = CMotion.motionless

        #expect(motion.velocity == .zero)
        #expect(motion.accelerationIntent == .idle)
        #expect(motion.accumulator == .zero)
    }

    @Test func switchingAccelerationIntentToIdleClearsAccelerationOnly() async throws {
        let expectedVelocity = SIMD3<Double>(1, 2, 3)
        let accelerationIntent = CMotion.AccelerationIntent.accelerating(
            SIMD3<Double>(7, 8, 9)
        )
        let expectedImpulse = SIMD3<Double>(10, 11, 12)
        var motion = CMotion(
            velocity: expectedVelocity,
            accelerationIntent: accelerationIntent,
            impulse: expectedImpulse
        )
        motion.accumulator.acceleration = SIMD3<Double>(4, 5, 6)

        motion.accelerationIntent = .idle

        #expect(motion.accelerationIntent == .idle)
        #expect(motion.acceleration == .zero)
        #expect(motion.impulse == expectedImpulse)
        #expect(motion.velocity == expectedVelocity)
    }

    @Test func switchingAccelerationIntentToAcceleratingPreservesAccumulator() async throws {
        let expectedImpulse = SIMD3<Double>(4, 5, 6)
        var motion = CMotion(
            velocity: .zero,
            accelerationIntent: .idle,
            impulse: expectedImpulse
        )
        let expectedAcceleration = SIMD3<Double>(1, 2, 3)
        motion.accumulator.acceleration = expectedAcceleration

        let expectedIntent = CMotion.AccelerationIntent.accelerating(
            SIMD3<Double>(7, 8, 9)
        )
        motion.accelerationIntent = expectedIntent

        #expect(motion.accelerationIntent == expectedIntent)
        #expect(motion.acceleration == expectedAcceleration)
        #expect(motion.impulse == expectedImpulse)
    }
}
