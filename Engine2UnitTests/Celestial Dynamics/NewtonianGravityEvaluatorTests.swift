import Foundation
import simd
import Testing
@testable import Engine2

struct NewtonianGravityEvaluatorTests {
    private let gravitationalConstant = 6.67430e-11
    private let evaluator = NewtonianGravityEvaluator()

    @Test func sourceAndReceiverCompositionPreservesInputOrder() throws {
        let unitParameterMass = AstronomicalMass(
            kilograms: 1 / gravitationalConstant
        )
        let receiverOnly = participant(
            sourceMass: nil,
            positionMeters: SIMD3(-2, 0, 0),
            receivesGravity: true
        )
        let sourceAndReceiver = participant(
            sourceMass: unitParameterMass,
            positionMeters: .zero,
            receivesGravity: true
        )
        let sourceOnly = participant(
            sourceMass: unitParameterMass,
            positionMeters: SIMD3(2, 0, 0),
            receivesGravity: false
        )

        let accelerations = try evaluator.accelerations(
            for: [receiverOnly, sourceAndReceiver, sourceOnly]
        )
        let reorderedAccelerations = try evaluator.accelerations(
            for: [sourceOnly, receiverOnly, sourceAndReceiver]
        )

        expectEqual(
            accelerations[0],
            SIMD3(0.3125, 0, 0)
        )
        expectEqual(
            accelerations[1],
            SIMD3(0.25, 0, 0)
        )
        #expect(accelerations[2] == .zero)
        #expect(reorderedAccelerations[0] == .zero)
        expectEqual(
            reorderedAccelerations[1],
            SIMD3(0.3125, 0, 0)
        )
        expectEqual(
            reorderedAccelerations[2],
            SIMD3(0.25, 0, 0)
        )
    }

    @Test func accelerationUsesAllThreeSpatialDimensions() throws {
        let source = participant(
            sourceMass: AstronomicalMass(
                kilograms: 1 / gravitationalConstant
            ),
            positionMeters: .zero,
            receivesGravity: false
        )
        let receiver = participant(
            sourceMass: nil,
            positionMeters: SIMD3(0, 0, 2),
            receivesGravity: true
        )

        let accelerations = try evaluator.accelerations(
            for: [source, receiver]
        )

        #expect(accelerations[0] == .zero)
        expectEqual(
            accelerations[1],
            SIMD3(0, 0, -0.25)
        )
    }

    @Test func oneSourceEvaluatesALargeReceiverOnlyPopulationInInputOrder() throws {
        let receiverCount = 10_000
        let source = participant(
            sourceMass: AstronomicalMass(
                kilograms: 1 / gravitationalConstant
            ),
            physicalRadiusMeters: 0.1,
            positionMeters: .zero,
            receivesGravity: false
        )
        var participants = [source]
        participants.reserveCapacity(receiverCount + 1)
        for receiverIndex in 0..<receiverCount {
            participants.append(
                participant(
                    sourceMass: nil,
                    positionMeters: SIMD3(
                        Double(receiverIndex + 2),
                        0,
                        0
                    ),
                    receivesGravity: true
                )
            )
        }

        let accelerations = try evaluator.accelerations(for: participants)

        #expect(accelerations.count == participants.count)
        #expect(accelerations[0] == .zero)
        expectEqual(
            accelerations[1],
            SIMD3(-0.25, 0, 0)
        )
        let lastDistance = Double(receiverCount + 1)
        expectEqual(
            accelerations[receiverCount],
            SIMD3(-1 / (lastDistance * lastDistance), 0, 0)
        )
    }

    @Test func contactIsRejectedOnlyForAnActiveSourceReceiverPair() throws {
        let firstSource = participant(
            sourceMass: .earth,
            physicalRadiusMeters: 1,
            positionMeters: .zero,
            receivesGravity: false
        )
        let secondSource = participant(
            sourceMass: .earth,
            physicalRadiusMeters: 1,
            positionMeters: SIMD3(1.5, 0, 0),
            receivesGravity: false
        )
        let retainedParticipants = [firstSource, secondSource]

        #expect(
            try evaluator.accelerations(for: retainedParticipants)
                == [.zero, .zero]
        )
        #expect(
            throws: NewtonianGravityEvaluationError.contact(
                firstBodyIndex: 0,
                secondBodyIndex: 1
            )
        ) {
            try evaluator.accelerations(
                for: [
                    firstSource,
                    participant(
                        sourceMass: secondSource.sourceMass,
                        physicalRadiusMeters: secondSource.physicalRadius.meters,
                        positionMeters: secondSource.positionMeters,
                        receivesGravity: true
                    )
                ]
            )
        }
        #expect([firstSource, secondSource] == retainedParticipants)
    }

    @Test func numericFailuresUseInputIndices() {
        let receiver = participant(
            sourceMass: nil,
            positionMeters: SIMD3(1, 0, 0),
            receivesGravity: true
        )
        let underflowingSource = participant(
            sourceMass: AstronomicalMass(
                kilograms: Double.leastNonzeroMagnitude
            ),
            positionMeters: .zero,
            receivesGravity: false
        )
        let overflowingOffset = [
            participant(
                sourceMass: .earth,
                positionMeters: SIMD3(-Double.greatestFiniteMagnitude, 0, 0),
                receivesGravity: true
            ),
            participant(
                sourceMass: .earth,
                positionMeters: SIMD3(Double.greatestFiniteMagnitude, 0, 0),
                receivesGravity: true
            )
        ]

        #expect(
            throws: NewtonianGravityEvaluationError.unrepresentableGravitationalParameter(
                bodyIndex: 1
            )
        ) {
            try evaluator.accelerations(
                for: [receiver, underflowingSource]
            )
        }
        #expect(
            throws: NewtonianGravityEvaluationError.unrepresentableInteraction(
                firstBodyIndex: 0,
                secondBodyIndex: 1
            )
        ) {
            try evaluator.accelerations(for: overflowingOffset)
        }
    }

    @Test func validationRefusalsUseTheOriginalParticipantIndex() throws {
        let negativeDistance = try JSONDecoder().decode(
            AstronomicalDistance.self,
            from: Data("{\"meters\":-1}".utf8)
        )
        let validReceiver = participant(
            sourceMass: nil,
            positionMeters: SIMD3(1, 0, 0),
            receivesGravity: true
        )

        #expect(
            throws: NewtonianGravityEvaluationError.invalidSourceMass(
                bodyIndex: 1
            )
        ) {
            try evaluator.accelerations(
                for: [
                    validReceiver,
                    participant(
                        sourceMass: .zero,
                        positionMeters: .zero,
                        receivesGravity: false
                    )
                ]
            )
        }
        #expect(
            throws: NewtonianGravityEvaluationError.invalidPhysicalRadius(
                bodyIndex: 1
            )
        ) {
            try evaluator.accelerations(
                for: [
                    validReceiver,
                    NewtonianGravityParticipant(
                        sourceMass: nil,
                        physicalRadius: negativeDistance,
                        positionMeters: SIMD3(2, 0, 0),
                        receivesGravity: true
                    )
                ]
            )
        }
        #expect(
            throws: NewtonianGravityEvaluationError.invalidPosition(
                bodyIndex: 1
            )
        ) {
            try evaluator.accelerations(
                for: [
                    validReceiver,
                    participant(
                        sourceMass: nil,
                        positionMeters: SIMD3(.nan, 0, 0),
                        receivesGravity: true
                    )
                ]
            )
        }
    }

    @Test func activePairRefusalsUseCanonicalInputOrder() {
        let participants = [
            participant(
                sourceMass: nil,
                physicalRadiusMeters: 1,
                positionMeters: .zero,
                receivesGravity: true
            ),
            participant(
                sourceMass: .earth,
                physicalRadiusMeters: 1,
                positionMeters: SIMD3(10, 0, 0),
                receivesGravity: false
            ),
            participant(
                sourceMass: nil,
                physicalRadiusMeters: 1,
                positionMeters: SIMD3(10, 0, 0),
                receivesGravity: true
            ),
            participant(
                sourceMass: .earth,
                physicalRadiusMeters: 1,
                positionMeters: SIMD3(0.5, 0, 0),
                receivesGravity: false
            )
        ]

        #expect(
            throws: NewtonianGravityEvaluationError.contact(
                firstBodyIndex: 0,
                secondBodyIndex: 3
            )
        ) {
            try evaluator.accelerations(for: participants)
        }
    }

    @Test func summingFiniteContributionsRefusesAnUnrepresentableAcceleration() {
        let receiver = participant(
            sourceMass: nil,
            positionMeters: .zero,
            receivesGravity: true
        )
        let sourceMass = AstronomicalMass(
            kilograms: Double.greatestFiniteMagnitude
        )
        let firstSource = participant(
            sourceMass: sourceMass,
            positionMeters: SIMD3(0.000_01, 0, 0),
            receivesGravity: false
        )
        let secondSource = participant(
            sourceMass: sourceMass,
            positionMeters: SIMD3(0.000_01, 0, 0),
            receivesGravity: false
        )

        #expect(
            throws: NewtonianGravityEvaluationError.unrepresentableAcceleration(
                bodyIndex: 0
            )
        ) {
            try evaluator.accelerations(
                for: [receiver, firstSource, secondSource]
            )
        }
    }

    private func participant(
        sourceMass: AstronomicalMass?,
        physicalRadiusMeters: Double = 0,
        positionMeters: SIMD3<Double>,
        receivesGravity: Bool
    ) -> NewtonianGravityParticipant {
        NewtonianGravityParticipant(
            sourceMass: sourceMass,
            physicalRadius: AstronomicalDistance(
                meters: physicalRadiusMeters
            ),
            positionMeters: positionMeters,
            receivesGravity: receivesGravity
        )
    }

    private func expectEqual(
        _ actual: SIMD3<Double>,
        _ expected: SIMD3<Double>
    ) {
        #expect(simd_distance(actual, expected) < 1e-12)
    }
}
