//
//  BallTests.swift
//  Engine2Tests
//
//  Created by Codex on 3/17/26.
//

import Testing
import simd
@testable import Engine2

struct BallTests {
    @Test func initSeedsMovementAndRotationState() async throws {
        let world = World()
        let expectedPosition = SIMD3<Float>(1, 2, 3)
        let expectedVelocity = SIMD3<Float>(4, 5, 6)
        let expectedAccelerationIntent = CMotion.AccelerationIntent.accelerating(SIMD3<Float>(1, 0, 0))
        let expectedImpulse = SIMD3<Float>(-1, 0.5, 2)
        let expectedRotation = simd_quatf(angle: .pi / 3, axis: SIMD3<Float>(0, 1, 0))
        let expectedAngularVelocity = SIMD3<Float>(0.1, 0.2, 0.3)
        let expectedAngularAcceleration = SIMD3<Float>(0.4, 0.5, 0.6)
        let expectedAngularImpulse = SIMD3<Float>(0.7, 0.8, 0.9)
        let expectedSelectionState = CSelectable.SelectionState.highlighted

        let ball = Ball(
            in: world,
            position: expectedPosition,
            velocity: expectedVelocity,
            accelerationIntent: expectedAccelerationIntent,
            impulse: expectedImpulse,
            rotation: expectedRotation,
            angularVelocity: expectedAngularVelocity,
            angularAcceleration: expectedAngularAcceleration,
            angularImpulse: expectedAngularImpulse,
            selectionState: expectedSelectionState
        )

        #expect(ball.position == expectedPosition)
        #expect(ball.velocity == expectedVelocity)
        #expect(ball.acceleration == .zero)
        #expect(ball.accelerationIntent == expectedAccelerationIntent)
        #expect(ball.impulse == expectedImpulse)
        #expect(ball.rotation.vector == expectedRotation.vector)
        #expect(ball.angularVelocity == expectedAngularVelocity)
        #expect(ball.angularAcceleration == expectedAngularAcceleration)
        #expect(ball.angularImpulse == expectedAngularImpulse)
        #expect(ball.meshID == .ball)
        #expect(ball.selectionState == expectedSelectionState)
        #expect(world.scaleComponents[ball.id] == nil)
    }

    @Test func initDefaultsMissingStateToZeroAndIdentity() async throws {
        let world = World()
        let ball = Ball(in: world)
        let expectedRotation = simd_quatf(angle: 0, axis: SIMD3<Float>(0, 0, 1))

        #expect(ball.position == .zero)
        #expect(ball.velocity == .zero)
        #expect(ball.acceleration == .zero)
        #expect(ball.accelerationIntent == .idle)
        #expect(ball.impulse == .zero)
        #expect(ball.rotation.vector == expectedRotation.vector)
        #expect(ball.angularVelocity == .zero)
        #expect(ball.angularAcceleration == .zero)
        #expect(ball.angularImpulse == .zero)
        #expect(ball.meshID == .ball)
        #expect(ball.selectionState == .unselected)
    }
}
