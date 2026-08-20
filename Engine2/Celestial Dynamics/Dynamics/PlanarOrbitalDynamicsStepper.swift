import Darwin
import simd

/// Advances prescribed and integrated bodies through one velocity-Verlet step.
///
/// Each force evaluation visits an unordered body pair once. The pair updates
/// either or both receivers according to ``GravityParticipation``. Prescribed
/// states supply moving gravity sources without receiving a numerical update.
nonisolated struct PlanarOrbitalDynamicsStepper: Sendable {
    let modelVersion: PlanarOrbitalDynamicsModelVersion

    /// Returns detached ending states after one positive finite interval.
    ///
    /// Inputs must use strict ``CelestialBodyID`` order. Contact in an active
    /// source-to-integrated-receiver interaction is rejected at both endpoint
    /// force evaluations rather than softened or divided through. Physical
    /// collision detection remains a separate Simulation responsibility.
    func step(
        bodies: [PlanarOrbitalBody],
        durationSeconds: Double
    ) throws(PlanarOrbitalDynamicsError) -> PlanarOrbitalDynamicsStepResult {
        switch modelVersion {
        case .velocityVerletV1:
            return try velocityVerletV1Step(
                bodies: bodies,
                durationSeconds: durationSeconds
            )
        }
    }

    private func velocityVerletV1Step(
        bodies: [PlanarOrbitalBody],
        durationSeconds: Double
    ) throws(PlanarOrbitalDynamicsError) -> PlanarOrbitalDynamicsStepResult {
        guard durationSeconds.isFinite, durationSeconds > 0 else {
            throw .invalidDurationSeconds
        }
        try validateBodies(bodies)

        let initialPositions = bodies.map { $0.initialState.position.meters }
        let initialAccelerations = try accelerations(
            for: bodies,
            at: initialPositions
        )
        let endPositions = try propagatedPositions(
            for: bodies,
            initialAccelerations: initialAccelerations,
            durationSeconds: durationSeconds
        )
        let endAccelerations = try accelerations(
            for: bodies,
            at: endPositions
        )
        let bodyStates = try propagatedStates(
            for: bodies,
            endPositions: endPositions,
            initialAccelerations: initialAccelerations,
            endAccelerations: endAccelerations,
            durationSeconds: durationSeconds
        )
        return PlanarOrbitalDynamicsStepResult(
            modelVersion: modelVersion,
            bodyStates: bodyStates
        )
    }

    private func validateBodies(
        _ bodies: [PlanarOrbitalBody]
    ) throws(PlanarOrbitalDynamicsError) {
        var identities: Set<CelestialBodyID> = []
        for body in bodies {
            guard identities.insert(body.id).inserted else {
                throw .duplicateBodyID(body.id)
            }
        }

        for index in bodies.indices.dropFirst() {
            let previousID = bodies[index - 1].id
            let currentID = bodies[index].id
            guard previousID < currentID else {
                throw .bodiesNotOrdered(previous: previousID, current: currentID)
            }
        }

        for body in bodies {
            guard body.massKilograms.isFinite, body.massKilograms >= 0 else {
                throw .invalidMass(body.id)
            }
            if body.gravityParticipation.isSource {
                guard body.massKilograms > 0 else {
                    throw .sourceRequiresPositiveMass(body.id)
                }
                let gravitationalParameter = GravitationalParameter
                    .newtonianGravitationalConstantCubicMetersPerKilogramSecondSquared
                    * body.massKilograms
                guard gravitationalParameter.isFinite,
                      gravitationalParameter > 0 else {
                    throw .unrepresentableGravitationalParameter(body.id)
                }
            }
            guard body.radiusMeters.isFinite, body.radiusMeters >= 0 else {
                throw .invalidRadius(body.id)
            }
            guard body.initialState.position.meters.isFinite,
                  body.initialState.velocity.metersPerSecond.isFinite else {
                throw .nonfiniteState(body.id)
            }
            if case let .prescribed(endState) = body.propagation {
                guard endState.position.meters.isFinite,
                      endState.velocity.metersPerSecond.isFinite else {
                    throw .nonfiniteState(body.id)
                }
            }
        }
    }

    private func accelerations(
        for bodies: [PlanarOrbitalBody],
        at positions: [SIMD2<Double>]
    ) throws(PlanarOrbitalDynamicsError) -> [SIMD2<Double>] {
        var accelerations = Array(
            repeating: SIMD2<Double>.zero,
            count: bodies.count
        )
        for firstIndex in bodies.indices {
            for secondIndex in (firstIndex + 1)..<bodies.count {
                let firstBody = bodies[firstIndex]
                let secondBody = bodies[secondIndex]
                let firstReceives = firstBody.propagation.isIntegrated
                    && firstBody.gravityParticipation.isReceiver
                    && secondBody.gravityParticipation.isSource
                let secondReceives = secondBody.propagation.isIntegrated
                    && secondBody.gravityParticipation.isReceiver
                    && firstBody.gravityParticipation.isSource
                guard firstReceives || secondReceives else {
                    continue
                }

                let offset = positions[secondIndex] - positions[firstIndex]
                let distance = hypot(offset.x, offset.y)
                let combinedRadius = firstBody.radiusMeters
                    + secondBody.radiusMeters
                guard distance.isFinite else {
                    throw .nonfiniteAcceleration(
                        firstReceives ? firstBody.id : secondBody.id
                    )
                }
                guard distance > combinedRadius else {
                    throw .contact(first: firstBody.id, second: secondBody.id)
                }
                let directionFromFirstToSecond = offset / distance
                if firstReceives {
                    let contribution = try accelerationContribution(
                        direction: directionFromFirstToSecond,
                        distance: distance,
                        source: secondBody,
                        receiverID: firstBody.id
                    )
                    accelerations[firstIndex] += contribution
                    guard accelerations[firstIndex].isFinite else {
                        throw .nonfiniteAcceleration(firstBody.id)
                    }
                }
                if secondReceives {
                    let contribution = try accelerationContribution(
                        direction: -directionFromFirstToSecond,
                        distance: distance,
                        source: firstBody,
                        receiverID: secondBody.id
                    )
                    accelerations[secondIndex] += contribution
                    guard accelerations[secondIndex].isFinite else {
                        throw .nonfiniteAcceleration(secondBody.id)
                    }
                }
            }
        }
        return accelerations
    }

    private func accelerationContribution(
        direction: SIMD2<Double>,
        distance: Double,
        source: PlanarOrbitalBody,
        receiverID: CelestialBodyID
    ) throws(PlanarOrbitalDynamicsError) -> SIMD2<Double> {
        let gravitationalParameter = GravitationalParameter
            .newtonianGravitationalConstantCubicMetersPerKilogramSecondSquared
            * source.massKilograms
        let magnitude = gravitationalParameter / distance / distance
        let contribution = direction * magnitude
        guard contribution.isFinite else {
            throw .nonfiniteAcceleration(receiverID)
        }
        return contribution
    }

    private func propagatedPositions(
        for bodies: [PlanarOrbitalBody],
        initialAccelerations: [SIMD2<Double>],
        durationSeconds: Double
    ) throws(PlanarOrbitalDynamicsError) -> [SIMD2<Double>] {
        var positions: [SIMD2<Double>] = []
        positions.reserveCapacity(bodies.count)
        for (index, body) in bodies.enumerated() {
            let position: SIMD2<Double>
            switch body.propagation {
            case .integrated:
                let velocityDisplacement = body.initialState.velocity.metersPerSecond
                    * durationSeconds
                let accelerationDisplacement = initialAccelerations[index]
                    * (0.5 * durationSeconds * durationSeconds)
                position = body.initialState.position.meters
                    + velocityDisplacement
                    + accelerationDisplacement
            case let .prescribed(endState):
                position = endState.position.meters
            }
            guard position.isFinite else {
                throw .nonfiniteState(body.id)
            }
            positions.append(position)
        }
        return positions
    }

    private func propagatedStates(
        for bodies: [PlanarOrbitalBody],
        endPositions: [SIMD2<Double>],
        initialAccelerations: [SIMD2<Double>],
        endAccelerations: [SIMD2<Double>],
        durationSeconds: Double
    ) throws(PlanarOrbitalDynamicsError) -> [PlanarOrbitalBodyState] {
        var bodyStates: [PlanarOrbitalBodyState] = []
        bodyStates.reserveCapacity(bodies.count)
        for (index, body) in bodies.enumerated() {
            let state: PlanarStateVector
            switch body.propagation {
            case .integrated:
                let averageAcceleration = (initialAccelerations[index]
                    + endAccelerations[index]) * 0.5
                let velocity = body.initialState.velocity.metersPerSecond
                    + averageAcceleration * durationSeconds
                guard velocity.isFinite else {
                    throw .nonfiniteState(body.id)
                }
                state = PlanarStateVector(
                    position: PlanarPosition(meters: endPositions[index]),
                    velocity: PlanarVelocity(metersPerSecond: velocity)
                )
            case let .prescribed(endState):
                state = endState
            }
            bodyStates.append(
                PlanarOrbitalBodyState(id: body.id, state: state)
            )
        }
        return bodyStates
    }
}
