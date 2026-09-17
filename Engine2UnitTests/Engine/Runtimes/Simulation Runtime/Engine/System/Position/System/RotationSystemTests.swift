import Testing
import simd
@testable import Engine2

struct RotationSystemTests {
    @Test func updatesExistingRowsWithoutChangingComponentTopology() async throws {
        var world = World()
        let entity = EntityID(index: 0, generation: 0)

        let initialRotationAxis = SIMD3<Float>(0, 0, 1)
        let initialRotation = RotationComponent(rotation: .identity)
        world.components[RotationComponent.self].insert(
            initialRotation,
            for: entity
        )
        let initialAngularVelocity = AngularVelocityComponent(
            angularVelocity: SIMD3<Float>(0, 0, 1)
        )
        world.components[AngularVelocityComponent.self].insert(
            initialAngularVelocity,
            for: entity
        )
        let initialAccumulator = AngularMotionAccumulatorComponent(
            angularAcceleration: SIMD3<Float>(0, 0, 2),
            angularImpulse: SIMD3<Float>(0, 0, 0.5)
        )
        world.components[AngularMotionAccumulatorComponent.self].insert(
            initialAccumulator,
            for: entity
        )
        let expectedRotationEntities = world.components[RotationComponent.self].entities
        let expectedRotationSparse = world.components[RotationComponent.self].sparse
        let expectedRotationCount = world.components[RotationComponent.self].dense.count
        let expectedAngularVelocityEntities = world.components[AngularVelocityComponent.self].entities
        let expectedAngularVelocitySparse = world.components[AngularVelocityComponent.self].sparse
        let expectedAngularVelocityCount = world.components[AngularVelocityComponent.self].dense.count
        let expectedAccumulatorEntities = world.components[AngularMotionAccumulatorComponent.self].entities
        let expectedAccumulatorSparse = world.components[AngularMotionAccumulatorComponent.self].sparse
        let expectedAccumulatorCount = world.components[AngularMotionAccumulatorComponent.self].dense.count

        var system = RotationSystem()
        system.update(world: &world, deltaTime: 0.5)

        let expectedAngularVelocity = SIMD3<Float>(0, 0, 2.5)
        let expectedRotation = simd_quatf(
            angle: 1.25,
            axis: initialRotationAxis
        )

        #expect(world.components[AngularVelocityComponent.self][entity]?.angularVelocity == expectedAngularVelocity)
        #expect(quaternionVectorsApproximatelyEqual(
            world.components[RotationComponent.self][entity]?.rotation.vector,
            expectedRotation.vector
        ))
        #expect(world.components[AngularMotionAccumulatorComponent.self][entity]?.angularAcceleration == .zero)
        #expect(world.components[AngularMotionAccumulatorComponent.self][entity]?.angularImpulse == .zero)
        #expect(world.components[RotationComponent.self].entities == expectedRotationEntities)
        #expect(world.components[RotationComponent.self].sparse == expectedRotationSparse)
        #expect(world.components[RotationComponent.self].dense.count == expectedRotationCount)
        #expect(world.components[AngularVelocityComponent.self].entities == expectedAngularVelocityEntities)
        #expect(world.components[AngularVelocityComponent.self].sparse == expectedAngularVelocitySparse)
        #expect(world.components[AngularVelocityComponent.self].dense.count == expectedAngularVelocityCount)
        #expect(world.components[AngularMotionAccumulatorComponent.self].entities == expectedAccumulatorEntities)
        #expect(world.components[AngularMotionAccumulatorComponent.self].sparse == expectedAccumulatorSparse)
        #expect(world.components[AngularMotionAccumulatorComponent.self].dense.count == expectedAccumulatorCount)
    }

    @Test func integratesRotationWithoutAccumulatorComponent() async throws {
        var world = World()
        let entity = EntityID(index: 0, generation: 0)

        let rotationAxis = SIMD3<Float>(0, 1, 0)
        let initialRotationValue = simd_quatf(
            angle: .pi / 6,
            axis: rotationAxis
        )
        let initialRotation = RotationComponent(rotation: initialRotationValue)
        world.components[RotationComponent.self].insert(
            initialRotation,
            for: entity
        )
        let angularVelocityValue = SIMD3<Float>(0, 2, 0)
        let angularVelocity = AngularVelocityComponent(
            angularVelocity: angularVelocityValue
        )
        world.components[AngularVelocityComponent.self].insert(
            angularVelocity,
            for: entity
        )

        var system = RotationSystem()
        system.update(world: &world, deltaTime: 0.25)

        let expectedRotation = simd_quatf(
            angle: .pi / 6 + 0.5,
            axis: rotationAxis
        )

        #expect(world.components[AngularVelocityComponent.self][entity]?.angularVelocity == angularVelocityValue)
        #expect(quaternionVectorsApproximatelyEqual(
            world.components[RotationComponent.self][entity]?.rotation.vector,
            expectedRotation.vector
        ))
        #expect(world.components[AngularMotionAccumulatorComponent.self][entity] == nil)
        #expect(world.components[AngularMotionAccumulatorComponent.self].dense.isEmpty)
        #expect(world.components[AngularMotionAccumulatorComponent.self].entities.isEmpty)
        #expect(world.components[AngularMotionAccumulatorComponent.self].sparse.isEmpty)
    }

    @Test func incompleteEntityWithoutRotationIsLeftUnchanged() {
        var world = World()
        let entity = EntityID(index: 0, generation: 0)
        let expectedVelocity = AngularVelocityComponent(
            angularVelocity: SIMD3<Float>(1, 2, 3)
        )
        let expectedAccumulator = AngularMotionAccumulatorComponent(
            angularAcceleration: SIMD3<Float>(4, 5, 6),
            angularImpulse: SIMD3<Float>(7, 8, 9)
        )
        world.components[AngularVelocityComponent.self].insert(expectedVelocity, for: entity)
        world.components[AngularMotionAccumulatorComponent.self].insert(
            expectedAccumulator,
            for: entity
        )

        var system = RotationSystem()
        system.update(world: &world, deltaTime: 0.5)

        #expect(world.components[AngularVelocityComponent.self][entity] == expectedVelocity)
        #expect(
            world.components[AngularMotionAccumulatorComponent.self][entity] == expectedAccumulator
        )
        #expect(world.components[RotationComponent.self][entity] == nil)
    }
}

private func quaternionVectorsApproximatelyEqual(_ lhs: SIMD4<Float>?, _ rhs: SIMD4<Float>, tolerance: Float = 0.000_1) -> Bool {
    guard let lhs else { return false }
    return simd_length(lhs - rhs) <= tolerance
}
