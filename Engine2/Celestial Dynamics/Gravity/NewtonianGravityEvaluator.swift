import Darwin
import simd

/// Calculates collective Newtonian acceleration without owning or mutating simulation state.
///
/// The evaluator validates every participant in input order, then visits each
/// active source-receiver pair once in canonical input-index order. After
/// validation, interaction work is proportional to source count times receiver
/// count; receiver-only pairs are not scanned. It applies no softening and
/// refuses contact instead of resolving it. The returned acceleration array
/// retains the exact input count and order; source-only participants receive a
/// zero entry.
nonisolated struct NewtonianGravityEvaluator: Sendable {
    /// Newtonian gravitational constant in cubic meters per kilogram-second squared.
    private static let gravitationalConstant = 6.67430e-11

    /// Returns one acceleration vector per participant without mutating the input.
    ///
    /// A pair interacts when either participant receives gravity and the other
    /// supplies `sourceMass`. Error indices always address the original
    /// `participants` array.
    func accelerations(
        for participants: [NewtonianGravityParticipant]
    ) throws(NewtonianGravityEvaluationError) -> [SIMD3<Double>] {
        let gravitationalParameters = try validatedGravitationalParameters(
            for: participants
        )
        var accelerations = Array(
            repeating: SIMD3<Double>.zero,
            count: participants.count
        )
        let sourceIndices = gravitationalParameters.indices.filter {
            gravitationalParameters[$0] != nil
        }
        let receiverIndices = participants.indices.filter {
            participants[$0].receivesGravity
        }
        try addActiveInteractions(
            among: participants,
            sourceIndices: sourceIndices,
            receiverIndices: receiverIndices,
            gravitationalParameters: gravitationalParameters,
            accelerations: &accelerations
        )

        return accelerations
    }

    private func validatedGravitationalParameters(
        for participants: [NewtonianGravityParticipant]
    ) throws(NewtonianGravityEvaluationError) -> [Double?] {
        var gravitationalParameters: [Double?] = []
        gravitationalParameters.reserveCapacity(participants.count)

        for (index, participant) in participants.enumerated() {
            gravitationalParameters.append(
                try validatedGravitationalParameter(
                    for: participant,
                    bodyIndex: index
                )
            )
        }

        return gravitationalParameters
    }

    private func validatedGravitationalParameter(
        for participant: NewtonianGravityParticipant,
        bodyIndex: Int
    ) throws(NewtonianGravityEvaluationError) -> Double? {
        guard participant.positionMeters.isFinite else {
            throw .invalidPosition(bodyIndex: bodyIndex)
        }
        guard participant.physicalRadius.meters.isFinite,
              participant.physicalRadius.meters >= 0 else {
            throw .invalidPhysicalRadius(bodyIndex: bodyIndex)
        }
        guard let sourceMass = participant.sourceMass else {
            return nil
        }
        guard sourceMass.kilograms.isFinite,
              sourceMass.kilograms > 0 else {
            throw .invalidSourceMass(bodyIndex: bodyIndex)
        }

        let gravitationalParameter = Self.gravitationalConstant
            * sourceMass.kilograms
        guard gravitationalParameter.isFinite,
              gravitationalParameter > 0 else {
            throw .unrepresentableGravitationalParameter(
                bodyIndex: bodyIndex
            )
        }

        return gravitationalParameter
    }

    private func addActiveInteractions(
        among participants: [NewtonianGravityParticipant],
        sourceIndices: [Int],
        receiverIndices: [Int],
        gravitationalParameters: [Double?],
        accelerations: inout [SIMD3<Double>]
    ) throws(NewtonianGravityEvaluationError) {
        var firstSourceOffset = sourceIndices.startIndex
        var firstReceiverOffset = receiverIndices.startIndex

        for firstIndex in participants.indices {
            while firstSourceOffset < sourceIndices.endIndex,
                  sourceIndices[firstSourceOffset] <= firstIndex {
                firstSourceOffset += 1
            }
            while firstReceiverOffset < receiverIndices.endIndex,
                  receiverIndices[firstReceiverOffset] <= firstIndex {
                firstReceiverOffset += 1
            }

            var sourceOffset = participants[firstIndex].receivesGravity
                ? firstSourceOffset
                : sourceIndices.endIndex
            var receiverOffset = gravitationalParameters[firstIndex] != nil
                ? firstReceiverOffset
                : receiverIndices.endIndex

            while sourceOffset < sourceIndices.endIndex
                    || receiverOffset < receiverIndices.endIndex {
                let nextSourceIndex = sourceOffset < sourceIndices.endIndex
                    ? sourceIndices[sourceOffset]
                    : participants.endIndex
                let nextReceiverIndex = receiverOffset < receiverIndices.endIndex
                    ? receiverIndices[receiverOffset]
                    : participants.endIndex
                let secondIndex = min(nextSourceIndex, nextReceiverIndex)

                if nextSourceIndex == secondIndex {
                    sourceOffset += 1
                }
                if nextReceiverIndex == secondIndex {
                    receiverOffset += 1
                }
                try addInteraction(
                    between: firstIndex,
                    and: secondIndex,
                    participants: participants,
                    gravitationalParameters: gravitationalParameters,
                    accelerations: &accelerations
                )
            }
        }
    }

    private func addInteraction(
        between firstIndex: Int,
        and secondIndex: Int,
        participants: [NewtonianGravityParticipant],
        gravitationalParameters: [Double?],
        accelerations: inout [SIMD3<Double>]
    ) throws(NewtonianGravityEvaluationError) {
        let firstReceivesFromSecond = participants[firstIndex].receivesGravity
            && gravitationalParameters[secondIndex] != nil
        let secondReceivesFromFirst = participants[secondIndex].receivesGravity
            && gravitationalParameters[firstIndex] != nil
        guard firstReceivesFromSecond || secondReceivesFromFirst else {
            return
        }

        let offsetFromFirstToSecond = participants[secondIndex].positionMeters
            - participants[firstIndex].positionMeters
        let distance = hypot(
            hypot(offsetFromFirstToSecond.x, offsetFromFirstToSecond.y),
            offsetFromFirstToSecond.z
        )
        let combinedRadius = participants[firstIndex].physicalRadius.meters
            + participants[secondIndex].physicalRadius.meters
        guard offsetFromFirstToSecond.isFinite,
              distance.isFinite,
              combinedRadius.isFinite else {
            throw .unrepresentableInteraction(
                firstBodyIndex: firstIndex,
                secondBodyIndex: secondIndex
            )
        }
        guard distance > combinedRadius else {
            throw .contact(
                firstBodyIndex: firstIndex,
                secondBodyIndex: secondIndex
            )
        }

        let directionFromFirstToSecond = offsetFromFirstToSecond / distance
        if firstReceivesFromSecond {
            guard let secondGravitationalParameter = gravitationalParameters[secondIndex] else {
                preconditionFailure("An active gravity source must have a validated Newtonian parameter.")
            }
            try addAcceleration(
                direction: directionFromFirstToSecond,
                gravitationalParameter: secondGravitationalParameter,
                distance: distance,
                receiverIndex: firstIndex,
                firstBodyIndex: firstIndex,
                secondBodyIndex: secondIndex,
                accelerations: &accelerations
            )
        }
        if secondReceivesFromFirst {
            guard let firstGravitationalParameter = gravitationalParameters[firstIndex] else {
                preconditionFailure("An active gravity source must have a validated Newtonian parameter.")
            }
            try addAcceleration(
                direction: -directionFromFirstToSecond,
                gravitationalParameter: firstGravitationalParameter,
                distance: distance,
                receiverIndex: secondIndex,
                firstBodyIndex: firstIndex,
                secondBodyIndex: secondIndex,
                accelerations: &accelerations
            )
        }
    }

    private func addAcceleration(
        direction: SIMD3<Double>,
        gravitationalParameter: Double,
        distance: Double,
        receiverIndex: Int,
        firstBodyIndex: Int,
        secondBodyIndex: Int,
        accelerations: inout [SIMD3<Double>]
    ) throws(NewtonianGravityEvaluationError) {
        let magnitude = gravitationalParameter / distance / distance
        let contribution = direction * magnitude
        guard direction.isFinite,
              magnitude.isFinite,
              magnitude > 0,
              contribution.isFinite,
              !contribution.isZero else {
            throw .unrepresentableInteraction(
                firstBodyIndex: firstBodyIndex,
                secondBodyIndex: secondBodyIndex
            )
        }

        let acceleration = accelerations[receiverIndex] + contribution
        guard acceleration.isFinite else {
            throw .unrepresentableAcceleration(bodyIndex: receiverIndex)
        }
        accelerations[receiverIndex] = acceleration
    }
}
