import Darwin
import Testing
import simd

@testable import Engine2

nonisolated struct PlanarOrbitalDynamicsStepperTests {
    private let stepper = PlanarOrbitalDynamicsStepper(
        modelVersion: .velocityVerletV1
    )

    @Test func velocityVerletAdvancesCircularMutualGravityWithoutBarycenterDrift() throws {
        let firstID = CelestialBodyID(rawValue: 1)
        let secondID = CelestialBodyID(rawValue: 2)
        let firstMassKilograms = 2e20
        let secondMassKilograms = 1e20
        let totalMassKilograms = firstMassKilograms + secondMassKilograms
        let separationMeters = 1e6
        let firstOrbitalRadiusMeters = separationMeters
            * secondMassKilograms / totalMassKilograms
        let secondOrbitalRadiusMeters = separationMeters
            * firstMassKilograms / totalMassKilograms
        let angularVelocity = (
            GravitationalParameter
                .newtonianGravitationalConstantCubicMetersPerKilogramSecondSquared
                * totalMassKilograms
                / (separationMeters * separationMeters * separationMeters)
        ).squareRoot()
        let bodies = [
            integratedBody(
                id: firstID,
                massKilograms: firstMassKilograms,
                position: SIMD2(-firstOrbitalRadiusMeters, 0),
                velocity: SIMD2(0, -angularVelocity * firstOrbitalRadiusMeters),
                gravityParticipation: .sourceAndReceiver
            ),
            integratedBody(
                id: secondID,
                massKilograms: secondMassKilograms,
                position: SIMD2(secondOrbitalRadiusMeters, 0),
                velocity: SIMD2(0, angularVelocity * secondOrbitalRadiusMeters),
                gravityParticipation: .sourceAndReceiver
            )
        ]

        let result = try stepper.step(
            bodies: bodies,
            durationSeconds: 10
        )
        let firstState = try #require(result.state(for: firstID))
        let secondState = try #require(result.state(for: secondID))
        let weightedPosition = firstState.position.meters * firstMassKilograms
            + secondState.position.meters * secondMassKilograms
        let totalMomentum = firstState.velocity.metersPerSecond * firstMassKilograms
            + secondState.velocity.metersPerSecond * secondMassKilograms
        let accelerationResponseRatio = abs(
            firstState.velocity.metersPerSecond.x
                / secondState.velocity.metersPerSecond.x
        )

        #expect(result.modelVersion == .velocityVerletV1)
        #expect(simd_length(weightedPosition) <= totalMassKilograms * 1e-9)
        #expect(simd_length(totalMomentum) <= totalMassKilograms * 1e-9)
        #expect(
            approximatelyEqual(
                accelerationResponseRatio,
                secondMassKilograms / firstMassKilograms,
                relativeTolerance: 1e-12
            )
        )
        #expect(
            approximatelyEqual(
                simd_length(firstState.position.meters),
                firstOrbitalRadiusMeters,
                relativeTolerance: 1e-10
            )
        )
        #expect(
            approximatelyEqual(
                simd_length(secondState.position.meters),
                secondOrbitalRadiusMeters,
                relativeTolerance: 1e-10
            )
        )
        #expect(firstState.position.meters.x > -firstOrbitalRadiusMeters)
        #expect(secondState.position.meters.x < secondOrbitalRadiusMeters)
    }

    @Test func sourceOnlyBodyAcceleratesPositiveMassReceiverOnlyBodyWithoutRecoil() throws {
        let probeID = CelestialBodyID(rawValue: 1)
        let source = integratedBody(
            id: .primaryStar,
            massKilograms: 1e15,
            radiusMeters: 10,
            gravityParticipation: .sourceOnly
        )
        let probe = integratedBody(
            id: probeID,
            massKilograms: 5e14,
            position: SIMD2(1_000, 0),
            velocity: SIMD2(0, 10),
            gravityParticipation: .receiverOnly
        )

        let result = try stepper.step(
            bodies: [source, probe],
            durationSeconds: 1
        )
        let propagatedSource = try #require(result.state(for: .primaryStar))
        let propagatedProbe = try #require(result.state(for: probeID))
        let initialAcceleration = GravitationalParameter
            .newtonianGravitationalConstantCubicMetersPerKilogramSecondSquared
            * source.massKilograms / 1_000 / 1_000

        #expect(propagatedSource == .zero)
        #expect(
            approximatelyEqual(
                propagatedProbe.position.meters.x,
                1_000 - initialAcceleration / 2,
                relativeTolerance: 1e-12
            )
        )
        #expect(propagatedProbe.position.meters.y == 10)
        #expect(propagatedProbe.velocity.metersPerSecond.x < 0)
        #expect(propagatedProbe.velocity.metersPerSecond.y < 10)
    }

    @Test func movingPrescribedSourceContributesItsEndStateToTheSecondForceEvaluation() throws {
        let probeID = CelestialBodyID(rawValue: 1)
        let sourceEndState = PlanarStateVector(
            position: PlanarPosition(meters: SIMD2(0, 100)),
            velocity: PlanarVelocity(metersPerSecond: SIMD2(0, 100))
        )
        let source = PlanarOrbitalBody(
            id: .primaryStar,
            massKilograms: 1e15,
            radiusMeters: 10,
            initialState: .zero,
            propagation: .prescribed(endState: sourceEndState),
            gravityParticipation: .sourceOnly
        )
        let probe = integratedBody(
            id: probeID,
            massKilograms: 5e14,
            position: SIMD2(1_000, 0),
            gravityParticipation: .receiverOnly
        )

        let result = try stepper.step(
            bodies: [source, probe],
            durationSeconds: 1
        )
        let propagatedSource = try #require(result.state(for: .primaryStar))
        let propagatedProbe = try #require(result.state(for: probeID))

        #expect(propagatedSource == sourceEndState)
        #expect(propagatedProbe.position.meters.y == 0)
        #expect(propagatedProbe.velocity.metersPerSecond.x < 0)
        #expect(propagatedProbe.velocity.metersPerSecond.y > 0)
    }

    @Test func stepPreservesStrictIdentityOrderAndReturnsDeterministicStructuralRefusals() throws {
        let firstID = CelestialBodyID(rawValue: 1)
        let secondID = CelestialBodyID(rawValue: 2)
        let first = integratedBody(id: firstID)
        let second = integratedBody(id: secondID)

        let result = try stepper.step(
            bodies: [first, second],
            durationSeconds: 1
        )

        #expect(result.bodyStates.map(\.id) == [firstID, secondID])
        #expect(
            throws: PlanarOrbitalDynamicsError.bodiesNotOrdered(
                previous: secondID,
                current: firstID
            )
        ) {
            try stepper.step(
                bodies: [second, first],
                durationSeconds: 1
            )
        }
        #expect(throws: PlanarOrbitalDynamicsError.duplicateBodyID(secondID)) {
            try stepper.step(
                bodies: [second, first, second],
                durationSeconds: 1
            )
        }
    }

    @Test func stepRejectsContactAndNonfinitePropagation() {
        let sourceID = CelestialBodyID(rawValue: 1)
        let receiverID = CelestialBodyID(rawValue: 2)
        let source = integratedBody(
            id: sourceID,
            massKilograms: 1e10,
            radiusMeters: 2,
            gravityParticipation: .sourceOnly
        )
        let contactingReceiver = integratedBody(
            id: receiverID,
            position: SIMD2(3, 0),
            radiusMeters: 1,
            gravityParticipation: .receiverOnly
        )
        let overflowingBody = integratedBody(
            id: sourceID,
            position: .zero,
            velocity: SIMD2(.greatestFiniteMagnitude, 0)
        )

        #expect(
            throws: PlanarOrbitalDynamicsError.contact(
                first: sourceID,
                second: receiverID
            )
        ) {
            try stepper.step(
                bodies: [source, contactingReceiver],
                durationSeconds: 1
            )
        }
        #expect(throws: PlanarOrbitalDynamicsError.nonfiniteState(sourceID)) {
            try stepper.step(
                bodies: [overflowingBody],
                durationSeconds: 2
            )
        }
    }

    @Test func stepRejectsASourceWhoseGravitationalParameterUnderflows() {
        let sourceID = CelestialBodyID(rawValue: 1)
        let source = integratedBody(
            id: sourceID,
            massKilograms: .leastNonzeroMagnitude,
            gravityParticipation: .sourceOnly
        )

        #expect(
            throws: PlanarOrbitalDynamicsError.unrepresentableGravitationalParameter(
                sourceID
            )
        ) {
            try stepper.step(
                bodies: [source],
                durationSeconds: 1
            )
        }
    }

    @Test func stepReturnsDetachedStatesWithoutMutatingInputs() throws {
        let bodyID = CelestialBodyID(rawValue: 1)
        let bodies = [
            integratedBody(
                id: bodyID,
                position: SIMD2(1, 2),
                velocity: SIMD2(3, 4)
            )
        ]
        let originalBodies = bodies

        let result = try stepper.step(
            bodies: bodies,
            durationSeconds: 2
        )
        let state = try #require(result.state(for: bodyID))

        #expect(bodies == originalBodies)
        #expect(state.position.meters == SIMD2(7, 10))
        #expect(state.velocity.metersPerSecond == SIMD2(3, 4))
    }

    private func integratedBody(
        id: CelestialBodyID,
        massKilograms: Double = 0,
        position: SIMD2<Double> = .zero,
        velocity: SIMD2<Double> = .zero,
        radiusMeters: Double = 0,
        gravityParticipation: GravityParticipation = .none
    ) -> PlanarOrbitalBody {
        PlanarOrbitalBody(
            id: id,
            massKilograms: massKilograms,
            radiusMeters: radiusMeters,
            initialState: PlanarStateVector(
                position: PlanarPosition(meters: position),
                velocity: PlanarVelocity(metersPerSecond: velocity)
            ),
            propagation: .integrated,
            gravityParticipation: gravityParticipation
        )
    }

    private func approximatelyEqual(
        _ first: Double,
        _ second: Double,
        relativeTolerance: Double
    ) -> Bool {
        let scale = max(abs(first), abs(second), 1)
        return abs(first - second) <= scale * relativeTolerance
    }
}
