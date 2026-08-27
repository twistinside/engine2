import Foundation
import Testing
import simd
@testable import Engine2

struct OrbitCircularizationEstimateEvaluatorTests {
    @Test func includesPrimaryVelocityAndRemovesRelativeVerticalVelocity() throws {
        let primaryVelocity = SIMD3<Double>(5, 7, 2)
        let currentVelocity = SIMD3<Double>(5, 27, 5)
        let fixture = makeFixture(
            radius: 2_000,
            primaryVelocity: primaryVelocity,
            entityVelocity: currentVelocity
        )

        let estimate = try #require(
            fixture.world.orbitCircularizationEstimate(for: fixture.entity)
        )
        let circularSpeed = sqrt(4_000_000 / 2_000)
        let expectedTarget = SIMD3<Double>(5, 7 + circularSpeed, 2)
        let expectedDelta = expectedTarget - currentVelocity
        let expectedFuel = -12_000 * expm1(-simd_length(expectedDelta) / 20_000)

        #expect(simd_length(estimate.targetVelocity - expectedTarget) < 1e-12)
        #expect(simd_length(estimate.deltaVelocity - expectedDelta) < 1e-12)
        #expect(abs(estimate.deltaV - simd_length(expectedDelta)) < 1e-12)
        #expect(abs(estimate.requiredFuel - expectedFuel) < 1e-12)
        #expect(estimate.hasSufficientFuel)
    }

    @Test func selectsClockwiseWhenItRequiresLessDeltaV() throws {
        let fixture = makeFixture(
            radius: 2_000,
            primaryVelocity: SIMD3<Double>(3, 4, 0),
            entityVelocity: SIMD3<Double>(3, -16, 0)
        )

        let estimate = try #require(
            fixture.world.orbitCircularizationEstimate(for: fixture.entity)
        )

        #expect(estimate.targetVelocity.y < 4)
    }

    @Test func equalBurnsSelectCounterclockwise() throws {
        let primaryVelocity = SIMD3<Double>(3, 4, 1)
        let fixture = makeFixture(
            radius: 2_000,
            primaryVelocity: primaryVelocity,
            entityVelocity: primaryVelocity
        )

        let estimate = try #require(
            fixture.world.orbitCircularizationEstimate(for: fixture.entity)
        )

        #expect(estimate.targetVelocity.y > primaryVelocity.y)
    }

    @Test func insufficientFuelRemainsAReadableEstimate() throws {
        let fixture = makeFixture(
            radius: 2_000,
            primaryVelocity: .zero,
            entityVelocity: .zero,
            remainingFuel: 1
        )

        let estimate = try #require(
            fixture.world.orbitCircularizationEstimate(for: fixture.entity)
        )

        #expect(estimate.requiredFuel > 1)
        #expect(!estimate.hasSufficientFuel)
    }

    @Test func contactWithThePrimaryHasNoEstimate() {
        let fixture = makeFixture(
            radius: 110,
            primaryVelocity: .zero,
            entityVelocity: .zero
        )

        #expect(fixture.world.orbitCircularizationEstimate(for: fixture.entity) == nil)
    }

    private func makeFixture(
        radius: Double,
        primaryVelocity: SIMD3<Double>,
        entityVelocity: SIMD3<Double>,
        remainingFuel: Double = 2_000
    ) -> (world: World, primary: EntityID, entity: EntityID) {
        let world = World()
        let primary = EntityID(index: 0, generation: 0)
        let entity = EntityID(index: 1, generation: 0)

        world.positionComponents.insert(CPosition(position: .zero), for: primary)
        world.motionComponents.insert(CMotion(velocity: primaryVelocity), for: primary)
        world.gravitySourceComponents.insert(
            CGravitySource(gravitationalParameter: 4_000_000),
            for: primary
        )
        world.collisionBodyComponents.insert(
            CCollisionBody(radius: 100, restitution: 0.35),
            for: primary
        )

        world.positionComponents.insert(
            CPosition(position: SIMD3<Double>(radius, 0, 0)),
            for: entity
        )
        world.motionComponents.insert(CMotion(velocity: entityVelocity), for: entity)
        world.orbitPrimaryComponents.insert(
            COrbitPrimary(primaryEntityID: primary),
            for: entity
        )
        world.collisionBodyComponents.insert(
            CCollisionBody(radius: 10, restitution: 0.35),
            for: entity
        )
        world.massComponents.insert(CMass(dryMass: 10_000), for: entity)
        world.propulsionComponents.insert(
            CPropulsion(maximumThrust: 300_000, exhaustVelocity: 20_000),
            for: entity
        )
        world.fuelComponents.insert(
            CFuel(capacity: 2_000, remaining: remainingFuel),
            for: entity
        )

        return (world, primary, entity)
    }
}
