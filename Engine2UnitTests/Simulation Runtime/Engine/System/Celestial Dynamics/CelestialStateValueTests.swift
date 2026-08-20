import Foundation
import Testing
@testable import Engine2

struct CelestialStateValueTests {
    @Test func orbitalStateMutatesWithoutChangingItsAuthority() {
        var motion = COrbitalMotion(
            orbitalState: .zero,
            authority: .integrated
        )
        let expectedState = PlanarStateVector(
            position: PlanarPosition(meters: SIMD2<Double>(10, -20)),
            velocity: PlanarVelocity(metersPerSecond: SIMD2<Double>(3, 4))
        )

        motion.orbitalState = expectedState

        #expect(motion.orbitalState == expectedState)
        #expect(motion.authority == .integrated)
    }

    @Test func timelineAdvancementDoesNotInvalidateAnUnchangedPredictionBasis() {
        var timeline = CelestialTimeline(
            epoch: .zero,
            predictionBasisRevision: .zero
        )
        let expectedEpoch = CelestialEpoch(
            secondsSinceReferenceEpoch: 60
        )

        timeline.commit(
            epoch: expectedEpoch,
            predictionBasisRevision: .zero
        )

        #expect(timeline.epoch == expectedEpoch)
        #expect(timeline.predictionBasisRevision == .zero)
    }

    @Test func stellarEmissionRoundTripsAndRejectsNonpositiveDecodedLuminosity() throws {
        let emission = CStellarEmission(
            luminosity: .solarLuminosity,
            effectiveTemperature: ThermodynamicTemperature(kelvin: 5_772),
            xuvLuminosityFraction: 0.000_1
        )

        let encoded = try JSONEncoder().encode(emission)
        let decoded = try JSONDecoder().decode(CStellarEmission.self, from: encoded)

        #expect(decoded == emission)

        let invalidJSON = Data(
            #"{"luminosity":{"watts":0},"effectiveTemperature":{"kelvin":5772},"xuvLuminosityFraction":0.0001}"#.utf8
        )
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(CStellarEmission.self, from: invalidJSON)
        }
    }
}
