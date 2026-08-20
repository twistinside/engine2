import Foundation
import Testing
import simd

@testable import Engine2

nonisolated struct PlanarKeplerPropagationKernelTests {
    private let kernel = PlanarKeplerPropagationKernel()

    @Test func circularRailClosesAndPassesPinnedQuarterOrbitStates() {
        let rail = PlanarKeplerianRail(
            semiMajorAxis: .astronomicalUnit,
            eccentricity: .circular,
            longitudeOfPeriapsisRadians: 0,
            meanAnomalyAtEpochRadians: 0,
            epoch: .zero,
            gravitationalParameter: GravitationalParameter(
                primaryMass: .sun,
                orbitingMass: .zero
            )
        )
        let period = rail.orbitalPeriod.seconds
        let circularSpeed = (
            rail.gravitationalParameter.cubicMetersPerSecondSquared
                / rail.semiMajorAxis.meters
        ).squareRoot()

        let initial = kernel.state(on: rail, at: .zero)
        let quarter = kernel.state(
            on: rail,
            at: CelestialEpoch(secondsSinceReferenceEpoch: period / 4)
        )
        let completed = kernel.state(
            on: rail,
            at: CelestialEpoch(secondsSinceReferenceEpoch: period)
        )

        #expect(vector(initial.position.meters, approximatelyEquals: SIMD2<Double>(rail.semiMajorAxis.meters, 0)))
        #expect(vector(initial.velocity.metersPerSecond, approximatelyEquals: SIMD2<Double>(0, circularSpeed)))
        #expect(vector(quarter.position.meters, approximatelyEquals: SIMD2<Double>(0, rail.semiMajorAxis.meters)))
        #expect(vector(quarter.velocity.metersPerSecond, approximatelyEquals: SIMD2<Double>(-circularSpeed, 0)))
        #expect(vector(completed.position.meters, approximatelyEquals: initial.position.meters))
        #expect(vector(completed.velocity.metersPerSecond, approximatelyEquals: initial.velocity.metersPerSecond))
    }

    @Test func eccentricRailPinsApsidesAndConservedQuantities() {
        let semiMajorAxis = AstronomicalDistance(astronomicalUnits: 2)
        let eccentricity = OrbitalEccentricity(rawValue: 0.25)
        let rail = PlanarKeplerianRail(
            semiMajorAxis: semiMajorAxis,
            eccentricity: eccentricity,
            longitudeOfPeriapsisRadians: 0,
            meanAnomalyAtEpochRadians: 0,
            epoch: .zero,
            gravitationalParameter: GravitationalParameter(
                primaryMass: .sun,
                orbitingMass: .zero
            )
        )
        let apoapsisEpoch = CelestialEpoch(
            secondsSinceReferenceEpoch: rail.orbitalPeriod.seconds / 2
        )
        let intermediateEpoch = CelestialEpoch(
            secondsSinceReferenceEpoch: rail.orbitalPeriod.seconds / 4
        )

        let periapsis = kernel.state(on: rail, at: .zero)
        let intermediate = kernel.state(on: rail, at: intermediateEpoch)
        let apoapsis = kernel.state(on: rail, at: apoapsisEpoch)
        #expect(
            approximatelyEqual(
                simd_length(periapsis.position.meters),
                semiMajorAxis.meters * (1 - eccentricity.rawValue)
            )
        )
        #expect(
            approximatelyEqual(
                simd_length(apoapsis.position.meters),
                semiMajorAxis.meters * (1 + eccentricity.rawValue)
            )
        )
        let parameter = rail.gravitationalParameter.cubicMetersPerSecondSquared
        let expectedSpecificEnergy = -parameter / (2 * semiMajorAxis.meters)
        let expectedAngularMomentum = (
            parameter
                * semiMajorAxis.meters
                * (1 - eccentricity.rawValue * eccentricity.rawValue)
        ).squareRoot()
        for state in [periapsis, intermediate, apoapsis] {
            #expect(
                approximatelyEqual(
                    specificOrbitalEnergy(of: state, gravitationalParameter: parameter),
                    expectedSpecificEnergy
                )
            )
            #expect(
                approximatelyEqual(
                    scalarAngularMomentum(of: state),
                    expectedAngularMomentum
                )
            )
        }
    }

    @Test func validatingRailRejectsUnrepresentableDerivedCadence() {
        #expect(throws: PlanarKeplerianRailValidationError.unrepresentableMeanMotion) {
            try PlanarKeplerianRail(
                validatingSemiMajorAxis: AstronomicalDistance(meters: .greatestFiniteMagnitude),
                eccentricity: .circular,
                longitudeOfPeriapsisRadians: 0,
                meanAnomalyAtEpochRadians: 0,
                epoch: .zero,
                gravitationalParameter: GravitationalParameter(cubicMetersPerSecondSquared: 1)
            )
        }

        #expect(throws: PlanarKeplerianRailValidationError.unrepresentableOrbitalPeriod) {
            try PlanarKeplerianRail(
                validatingSemiMajorAxis: AstronomicalDistance(meters: 1e200),
                eccentricity: .circular,
                longitudeOfPeriapsisRadians: 0,
                meanAnomalyAtEpochRadians: 0,
                epoch: .zero,
                gravitationalParameter: GravitationalParameter(cubicMetersPerSecondSquared: 1e-20)
            )
        }
    }

    @Test func decodingRejectsRailWithUnrepresentableDerivedCadence() {
        let encodedRail = Data(
            """
            {
              "semiMajorAxis": { "meters": 1.7976931348623157e308 },
              "eccentricity": { "rawValue": 0 },
              "longitudeOfPeriapsisRadians": 0,
              "meanAnomalyAtEpochRadians": 0,
              "epoch": { "secondsSinceReferenceEpoch": 0 },
              "gravitationalParameter": { "cubicMetersPerSecondSquared": 1 }
            }
            """.utf8
        )

        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(PlanarKeplerianRail.self, from: encodedRail)
        }
    }

    @Test func validatedRailRoundTripsThroughPersistence() throws {
        let rail = PlanarKeplerianRail(
            semiMajorAxis: .astronomicalUnit,
            eccentricity: OrbitalEccentricity(rawValue: 0.1),
            longitudeOfPeriapsisRadians: 0.25,
            meanAnomalyAtEpochRadians: 0.5,
            epoch: .zero,
            gravitationalParameter: GravitationalParameter(
                primaryMass: .sun,
                orbitingMass: .zero
            )
        )

        let encodedRail = try JSONEncoder().encode(rail)
        let decodedRail = try JSONDecoder().decode(PlanarKeplerianRail.self, from: encodedRail)

        #expect(decodedRail == rail)
        #expect(decodedRail.isValidForPropagation)
    }

    @Test func decodingRejectsNegativeCelestialEpoch() {
        let encodedEpoch = Data(#"{"secondsSinceReferenceEpoch":-1}"#.utf8)

        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(CelestialEpoch.self, from: encodedEpoch)
        }
    }

    @Test func decodingRejectsNonfinitePlanarPosition() {
        let encodedPosition = Data(#"{"meters":["NaN",0]}"#.utf8)

        #expect(throws: DecodingError.self) {
            try decoderAcceptingNonfiniteStrings().decode(
                PlanarPosition.self,
                from: encodedPosition
            )
        }
    }

    @Test func decodingRejectsNonfinitePlanarVelocity() {
        let encodedVelocity = Data(#"{"metersPerSecond":[0,"Infinity"]}"#.utf8)

        #expect(throws: DecodingError.self) {
            try decoderAcceptingNonfiniteStrings().decode(
                PlanarVelocity.self,
                from: encodedVelocity
            )
        }
    }

    private func vector(
        _ first: SIMD2<Double>,
        approximatelyEquals second: SIMD2<Double>
    ) -> Bool {
        let difference = simd_length(first - second)
        let scale = max(simd_length(first), simd_length(second), 1)
        return difference <= scale * 1e-12
    }

    private func approximatelyEqual(_ first: Double, _ second: Double) -> Bool {
        let scale = max(abs(first), abs(second), 1)
        return abs(first - second) <= scale * 1e-11
    }

    private func decoderAcceptingNonfiniteStrings() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.nonConformingFloatDecodingStrategy = .convertFromString(
            positiveInfinity: "Infinity",
            negativeInfinity: "-Infinity",
            nan: "NaN"
        )
        return decoder
    }

    private func specificOrbitalEnergy(
        of state: PlanarStateVector,
        gravitationalParameter: Double
    ) -> Double {
        let speedSquared = simd_length_squared(state.velocity.metersPerSecond)
        let radius = simd_length(state.position.meters)
        return speedSquared / 2 - gravitationalParameter / radius
    }

    private func scalarAngularMomentum(of state: PlanarStateVector) -> Double {
        let position = state.position.meters
        let velocity = state.velocity.metersPerSecond
        return position.x * velocity.y - position.y * velocity.x
    }
}
