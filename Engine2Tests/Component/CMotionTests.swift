//
//  CMotionTests.swift
//  Engine2Tests
//
//  Created by Codex on 5/31/26.
//

import Testing
@testable import Engine2

struct CMotionTests {
    @Test func switchingAccelerationIntentToIdleClearsAccelerationOnly() async throws {
        var motion = CMotion(
            velocity: SIMD3<Float>(1, 2, 3),
            accelerationIntent: .accelerating(SIMD3<Float>(7, 8, 9)),
            impulse: SIMD3<Float>(10, 11, 12)
        )
        motion.accumulator.acceleration = SIMD3<Float>(4, 5, 6)

        motion.accelerationIntent = .idle

        #expect(motion.accelerationIntent == .idle)
        #expect(motion.acceleration == .zero)
        #expect(motion.impulse == SIMD3<Float>(10, 11, 12))
        #expect(motion.velocity == SIMD3<Float>(1, 2, 3))
    }

    @Test func switchingAccelerationIntentToAcceleratingPreservesAccumulator() async throws {
        var motion = CMotion(
            accelerationIntent: .idle,
            impulse: SIMD3<Float>(4, 5, 6)
        )
        motion.accumulator.acceleration = SIMD3<Float>(1, 2, 3)

        motion.accelerationIntent = .accelerating(SIMD3<Float>(7, 8, 9))

        #expect(motion.accelerationIntent == .accelerating(SIMD3<Float>(7, 8, 9)))
        #expect(motion.acceleration == SIMD3<Float>(1, 2, 3))
        #expect(motion.impulse == SIMD3<Float>(4, 5, 6))
    }
}
