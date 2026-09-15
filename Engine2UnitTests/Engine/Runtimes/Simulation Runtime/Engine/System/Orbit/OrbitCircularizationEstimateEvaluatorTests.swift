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
        let expectedAvailableDeltaV = 20_000 * log(12_000.0 / 10_000)
        let expectedFuel = -12_000 * expm1(-simd_length(expectedDelta) / 20_000)
        let expectedBurnDuration = expectedFuel * 20_000 / 300_000
        let expectedOrbitalPeriod = 2 * Double.pi * sqrt(
            2_000.0 * 2_000 * 2_000 / 4_000_000
        )

        #expect(estimate.direction == .counterclockwise)
        #expect(simd_length(estimate.targetVelocity - expectedTarget) < 1e-12)
        #expect(simd_length(estimate.deltaVelocity - expectedDelta) < 1e-12)
        #expect(abs(estimate.deltaV - simd_length(expectedDelta)) < 1e-12)
        #expect(abs(estimate.availableDeltaV - expectedAvailableDeltaV) < 1e-12)
        #expect(
            abs(
                estimate.deltaVMargin
                    - (expectedAvailableDeltaV - simd_length(expectedDelta))
            ) < 1e-12
        )
        #expect(abs(estimate.requiredFuel - expectedFuel) < 1e-12)
        #expect(abs(estimate.minimumBurnDuration - expectedBurnDuration) < 1e-12)
        #expect(abs(estimate.localOrbitalPeriod - expectedOrbitalPeriod) < 1e-12)
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
        #expect(estimate.direction == .clockwise)
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
        #expect(estimate.direction == .counterclockwise)
    }

    @Test func engagedAutopilotRetainsItsDirectionWhenTheOtherBurnIsCheaper() throws {
        let fixture = makeFixture(
            radius: 2_000,
            primaryVelocity: .zero,
            entityVelocity: SIMD3<Double>(0, 40, 0)
        )
        fixture.world.orbitCircularizationAutopilotComponents.update(for: fixture.entity) {
            $0 = .engaged(direction: .clockwise)
        }

        let estimate = try #require(
            fixture.world.orbitCircularizationEstimate(for: fixture.entity)
        )

        #expect(estimate.direction == .clockwise)
        #expect(estimate.targetVelocity.y < 0)
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
        #expect(estimate.availableDeltaV < estimate.deltaV)
        #expect(estimate.deltaVMargin < 0)
        #expect(!estimate.hasSufficientFuel)
    }

    @Test func cargoMassRaisesRequiredFuelForTheSameManeuver() throws {
        let emptyFixture = makeFixture(
            radius: 2_000,
            primaryVelocity: .zero,
            entityVelocity: .zero
        )
        let loadedFixture = makeFixture(
            radius: 2_000,
            primaryVelocity: .zero,
            entityVelocity: .zero,
            cargoOre: 8_000
        )

        let emptyEstimate = try #require(
            emptyFixture.world.orbitCircularizationEstimate(for: emptyFixture.entity)
        )
        let loadedEstimate = try #require(
            loadedFixture.world.orbitCircularizationEstimate(for: loadedFixture.entity)
        )

        #expect(loadedEstimate.deltaV == emptyEstimate.deltaV)
        #expect(loadedEstimate.requiredFuel > emptyEstimate.requiredFuel)
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
        remainingFuel: Double = 2_000,
        cargoOre: Double = 0
    ) -> (world: World, primary: EntityID, entity: EntityID) {
        let world = World()
        let primary = EntityID(index: 0, generation: 0)
        let entity = EntityID(index: 1, generation: 0)

        world.positionComponents.insert(PositionComponent(position: .zero), for: primary)
        world.motionComponents.insert(MotionComponent(velocity: primaryVelocity), for: primary)
        world.gravitySourceComponents.insert(
            GravitySourceComponent(gravitationalParameter: 4_000_000),
            for: primary
        )
        world.collisionBodyComponents.insert(
            CollisionBodyComponent(radius: 100, response: .solid(restitution: 0.35)),
            for: primary
        )

        world.positionComponents.insert(
            PositionComponent(position: SIMD3<Double>(radius, 0, 0)),
            for: entity
        )
        world.motionComponents.insert(MotionComponent(velocity: entityVelocity), for: entity)
        world.orbitPrimaryComponents.insert(
            OrbitPrimaryComponent(primaryEntityID: primary),
            for: entity
        )
        world.orbitCircularizationAutopilotComponents.insert(.idle, for: entity)
        world.collisionBodyComponents.insert(
            CollisionBodyComponent(radius: 10, response: .solid(restitution: 0.35)),
            for: entity
        )
        world.massComponents.insert(MassComponent(dryMass: 10_000), for: entity)
        world.propulsionComponents.insert(
            PropulsionComponent(maximumThrust: 300_000, exhaustVelocity: 20_000),
            for: entity
        )
        world.fuelComponents.insert(
            FuelComponent(capacity: 2_000, remaining: remainingFuel),
            for: entity
        )
        world.cargoComponents.insert(
            CargoComponent(capacity: 8_000, ore: cargoOre),
            for: entity
        )

        return (world, primary, entity)
    }
}
