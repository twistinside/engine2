import Testing
import simd
@testable import Engine2

struct SRotationTests {
    @Test func updatesExistingRowsWithoutChangingComponentTopology() async throws {
        var world = World()
        let entity = EntityID(index: 0, generation: 0)

        world.rotationComponents.insert(
            CRotation(rotation: simd_quatf(angle: 0, axis: SIMD3<Float>(0, 0, 1))),
            for: entity
        )
        world.angularVelocityComponents.insert(
            CAngularVelocity(angularVelocity: SIMD3<Float>(0, 0, 1)),
            for: entity
        )
        world.angularMotionAccumulatorComponents.insert(
            CAngularMotionAccumulator(
                angularAcceleration: SIMD3<Float>(0, 0, 2),
                angularImpulse: SIMD3<Float>(0, 0, 0.5)
            ),
            for: entity
        )
        let expectedRotationEntities = world.rotationComponents.entities
        let expectedRotationSparse = world.rotationComponents.sparse
        let expectedRotationCount = world.rotationComponents.dense.count
        let expectedAngularVelocityEntities = world.angularVelocityComponents.entities
        let expectedAngularVelocitySparse = world.angularVelocityComponents.sparse
        let expectedAngularVelocityCount = world.angularVelocityComponents.dense.count
        let expectedAccumulatorEntities = world.angularMotionAccumulatorComponents.entities
        let expectedAccumulatorSparse = world.angularMotionAccumulatorComponents.sparse
        let expectedAccumulatorCount = world.angularMotionAccumulatorComponents.dense.count

        let system = SRotation()
        system.update(world: &world, deltaTime: 0.5)

        let expectedAngularVelocity = SIMD3<Float>(0, 0, 2.5)
        let expectedRotation = simd_quatf(angle: 1.25, axis: SIMD3<Float>(0, 0, 1))

        #expect(world.angularVelocityComponents[entity]?.angularVelocity == expectedAngularVelocity)
        #expect(quaternionVectorsApproximatelyEqual(
            world.rotationComponents[entity]?.rotation.vector,
            expectedRotation.vector
        ))
        #expect(world.angularMotionAccumulatorComponents[entity]?.angularAcceleration == .zero)
        #expect(world.angularMotionAccumulatorComponents[entity]?.angularImpulse == .zero)
        #expect(world.rotationComponents.entities == expectedRotationEntities)
        #expect(world.rotationComponents.sparse == expectedRotationSparse)
        #expect(world.rotationComponents.dense.count == expectedRotationCount)
        #expect(world.angularVelocityComponents.entities == expectedAngularVelocityEntities)
        #expect(world.angularVelocityComponents.sparse == expectedAngularVelocitySparse)
        #expect(world.angularVelocityComponents.dense.count == expectedAngularVelocityCount)
        #expect(world.angularMotionAccumulatorComponents.entities == expectedAccumulatorEntities)
        #expect(world.angularMotionAccumulatorComponents.sparse == expectedAccumulatorSparse)
        #expect(world.angularMotionAccumulatorComponents.dense.count == expectedAccumulatorCount)
    }

    @Test func integratesRotationWithoutAccumulatorComponent() async throws {
        var world = World()
        let entity = EntityID(index: 0, generation: 0)

        world.rotationComponents.insert(
            CRotation(rotation: simd_quatf(angle: .pi / 6, axis: SIMD3<Float>(0, 1, 0))),
            for: entity
        )
        world.angularVelocityComponents.insert(
            CAngularVelocity(angularVelocity: SIMD3<Float>(0, 2, 0)),
            for: entity
        )

        let system = SRotation()
        system.update(world: &world, deltaTime: 0.25)

        let expectedRotation = simd_quatf(angle: .pi / 6 + 0.5, axis: SIMD3<Float>(0, 1, 0))

        #expect(world.angularVelocityComponents[entity]?.angularVelocity == SIMD3<Float>(0, 2, 0))
        #expect(quaternionVectorsApproximatelyEqual(
            world.rotationComponents[entity]?.rotation.vector,
            expectedRotation.vector
        ))
        #expect(world.angularMotionAccumulatorComponents[entity] == nil)
        #expect(world.angularMotionAccumulatorComponents.dense.isEmpty)
        #expect(world.angularMotionAccumulatorComponents.entities.isEmpty)
        #expect(world.angularMotionAccumulatorComponents.sparse.isEmpty)
    }

    @Test func incompleteEntityWithoutRotationIsLeftUnchanged() {
        var world = World()
        let entity = EntityID(index: 0, generation: 0)
        let expectedVelocity = CAngularVelocity(
            angularVelocity: SIMD3<Float>(1, 2, 3)
        )
        let expectedAccumulator = CAngularMotionAccumulator(
            angularAcceleration: SIMD3<Float>(4, 5, 6),
            angularImpulse: SIMD3<Float>(7, 8, 9)
        )
        world.angularVelocityComponents.insert(expectedVelocity, for: entity)
        world.angularMotionAccumulatorComponents.insert(
            expectedAccumulator,
            for: entity
        )

        SRotation().update(world: &world, deltaTime: 0.5)

        #expect(world.angularVelocityComponents[entity] == expectedVelocity)
        #expect(
            world.angularMotionAccumulatorComponents[entity] == expectedAccumulator
        )
        #expect(world.rotationComponents[entity] == nil)
    }
}

private func quaternionVectorsApproximatelyEqual(_ lhs: SIMD4<Float>?, _ rhs: SIMD4<Float>, tolerance: Float = 0.000_1) -> Bool {
    guard let lhs else { return false }
    return simd_length(lhs - rhs) <= tolerance
}
