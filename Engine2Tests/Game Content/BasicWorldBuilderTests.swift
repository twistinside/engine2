import Testing
import simd
@testable import Engine2

struct BasicWorldBuilderTests {
    @Test func basicWorldBuilderSeedsEveryDefaultBall() async throws {
        let world = BasicWorldBuilder().buildWorld()

        #expect(world.positionComponents.entities.count == 4)
        #expect(world.motionComponents.entities.count == 4)
        #expect(world.rotationComponents.entities.count == 4)
        #expect(world.angularVelocityComponents.entities.count == 4)
        #expect(world.angularMotionAccumulatorComponents.entities.count == 4)
        #expect(world.renderableComponents.entities.count == 4)
        #expect(world.selectableComponents.entities.count == 4)

        let entities = world.positionComponents.entities
        let expectedRotation = simd_quatf(angle: 0, axis: SIMD3<Float>(0, 0, 1))

        #expect(
            entities.compactMap { world.positionComponents[$0]?.position } == [
                SIMD3<Float>(-2, -1, 0),
                SIMD3<Float>(2, -1, 0),
                SIMD3<Float>(-1.5, 1.2, 0),
                SIMD3<Float>(1.7, 1.1, 0)
            ]
        )
        #expect(
            entities.compactMap { world.motionComponents[$0]?.velocity } == [
                SIMD3<Float>(0.65, 0.45, 0),
                SIMD3<Float>(-0.25, 0.35, 0),
                .zero,
                SIMD3<Float>(-0.45, -0.45, 0)
            ]
        )
        #expect(
            entities.compactMap {
                world.motionComponents[$0]?.accelerationIntent
            } == [
                .accelerating(SIMD3<Float>(0.02, 0.01, 0)),
                .idle,
                .accelerating(SIMD3<Float>(0.02, -0.02, 0)),
                .accelerating(SIMD3<Float>(-0.02, -0.01, 0))
            ]
        )

        for entity in entities {
            #expect(world.motionComponents[entity]?.acceleration == .zero)
            #expect(world.motionComponents[entity]?.impulse == .zero)
            #expect(
                world.rotationComponents[entity]?.rotation.vector ==
                expectedRotation.vector
            )
            #expect(world.angularVelocityComponents[entity]?.angularVelocity == .zero)
            #expect(
                world.angularMotionAccumulatorComponents[entity]?
                    .angularAcceleration == .zero
            )
            #expect(
                world.angularMotionAccumulatorComponents[entity]?
                    .angularImpulse == .zero
            )
            #expect(world.renderableComponents[entity]?.meshID == .ball)
            #expect(
                world.selectableComponents[entity]?.selectionState == .unselected
            )
        }
    }
}
