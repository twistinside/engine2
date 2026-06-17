//
//  WorldBuilderTests.swift
//  Engine2Tests
//
//  Created by Codex on 3/17/26.
//

import Testing
import simd
@testable import Engine2

struct WorldBuilderTests {
    @Test func basicWorldBuilderSeedsDefaultBall() async throws {
        let world = BasicWorldBuilder().buildWorld()

        #expect(world.positionComponents.entities.count == 4)

        let entity = try #require(world.positionComponents.entities.first)
        let expectedRotation = simd_quatf(angle: 0, axis: SIMD3<Float>(0, 0, 1))

        #expect(world.positionComponents[entity]?.position == SIMD3<Float>(-2, -1, 0))
        #expect(world.motionComponents[entity]?.velocity == SIMD3<Float>(0.65, 0.45, 0))
        #expect(world.motionComponents[entity]?.acceleration == .zero)
        #expect(world.motionComponents[entity]?.accelerationIntent == .accelerating(SIMD3<Float>(0.02, 0.01, 0)))
        #expect(world.motionComponents[entity]?.impulse == .zero)
        #expect(world.rotationComponents[entity]?.rotation.vector == expectedRotation.vector)
        #expect(world.angularVelocityComponents[entity]?.angularVelocity == .zero)
        #expect(world.angularMotionAccumulatorComponents[entity]?.angularAcceleration == .zero)
        #expect(world.angularMotionAccumulatorComponents[entity]?.angularImpulse == .zero)
    }
}
