import simd

/// Runs a finite workload through one authoritative Simulation Runtime.
///
/// The runner constructs no assembly or peer Runtime. It submits exact
/// cursor-qualified requests, measures complete fixed ticks, then validates all
/// authoritative and published entity state outside the measured interval.
struct HeadlessSimulationRunner {
    let configuration: HeadlessSimulationConfiguration

    func run() async throws(HeadlessSimulationError) -> HeadlessSimulationResult {
        let clock = ContinuousClock()
        let constructionStart = clock.now
        let worldBuilder = HeadlessSimulationWorldBuilder(
            entityCount: configuration.entityCount
        )
        let simulationRuntime = SimulationRuntime(
            worldBuilder: worldBuilder,
            configuration: .basicGame,
            inputBaseline: nil
        )
        let constructionDuration = constructionStart.duration(to: clock.now)
        let world = simulationRuntime.world

        try verifyEntityCounts(in: world)
        let initialReferenceState = try referenceState(in: world)

        var cursor = simulationRuntime.currentCursor
        for warmupTickIndex in 0..<configuration.warmupTickCount {
            let sample = await sampleOneTick(
                through: simulationRuntime,
                from: cursor,
                using: clock
            )
            cursor = try completedCursor(
                from: sample.outcome,
                expectedInitialCursor: cursor
            )
            if warmupTickIndex == 0 {
                try verifyFirstTickProgress(
                    in: world,
                    from: initialReferenceState
                )
            }
        }

        let initialMeasuredCursor = cursor
        var tickDurations: [Duration] = []
        tickDurations.reserveCapacity(configuration.measuredTickCount)

        for _ in 0..<configuration.measuredTickCount {
            let sample = await sampleOneTick(
                through: simulationRuntime,
                from: cursor,
                using: clock
            )
            cursor = try completedCursor(
                from: sample.outcome,
                expectedInitialCursor: cursor
            )
            tickDurations.append(sample.duration)
        }

        let finalState = try verifyFinalState(
            in: world,
            latestPresentation: simulationRuntime.latestPresentationSnapshot,
            initialReferenceState: initialReferenceState,
            worldBuilder: worldBuilder,
            finalCursor: cursor
        )

        return HeadlessSimulationResult(
            configuration: configuration,
            constructionDuration: constructionDuration,
            tickDurations: tickDurations,
            initialMeasuredCursor: initialMeasuredCursor,
            finalCursor: cursor,
            firstEntityPosition: finalState.firstPosition,
            lastEntityPosition: finalState.lastPosition,
            firstEntityRotation: finalState.firstRotation
        )
    }

    private func sampleOneTick(
        through advanceTarget: any PSimulationAdvanceTarget,
        from cursor: SimulationCursor,
        using clock: ContinuousClock
    ) async -> (outcome: SimulationAdvanceOutcome, duration: Duration) {
        let request = SimulationAdvanceRequest(
            expectedCursor: cursor,
            stepCount: .one,
            inputAssignment: .none
        )
        let start = clock.now
        let outcome = await advanceTarget.advance(request)
        return (outcome, start.duration(to: clock.now))
    }

    private func completedCursor(
        from outcome: SimulationAdvanceOutcome,
        expectedInitialCursor: SimulationCursor
    ) throws(HeadlessSimulationError) -> SimulationCursor {
        guard case let .completed(result) = outcome else {
            guard case let .rejected(rejection) = outcome else {
                throw .invariantViolation("The headless host received an unknown Simulation advance outcome.")
            }
            throw .advanceRejected(rejection)
        }
        guard result.initialCursor == expectedInitialCursor else {
            throw .invariantViolation(
                "A completed tick started at \(result.initialCursor), "
                + "not the submitted cursor \(expectedInitialCursor)."
            )
        }
        guard result.completedStepCount.rawValue == 1 else {
            throw .invariantViolation(
                "A one-tick request reported \(result.completedStepCount.rawValue) completed ticks."
            )
        }
        guard result.finalCursor.sessionID == expectedInitialCursor.sessionID,
              result.finalCursor.tick == expectedInitialCursor.tick.advanced()
        else {
            throw .invariantViolation(
                "A completed tick advanced from \(expectedInitialCursor) "
                + "to the unexpected cursor \(result.finalCursor)."
            )
        }
        guard result.finalPresentationSnapshot.cursor == result.finalCursor else {
            throw .invariantViolation("The completed tick returned a presentation for a different cursor.")
        }
        return result.finalCursor
    }

    private func verifyEntityCounts(in world: World) throws(HeadlessSimulationError) {
        try verify(
            world.angularMotionAccumulatorComponents.dense.count,
            in: .angularMotionAccumulator
        )
        try verify(world.angularVelocityComponents.dense.count, in: .angularVelocity)
        try verify(world.motionComponents.dense.count, in: .motion)
        try verify(world.positionComponents.dense.count, in: .position)
        try verify(world.renderableComponents.dense.count, in: .renderable)
        try verify(world.rotationComponents.dense.count, in: .rotation)
        try verify(world.selectableComponents.dense.count, in: .selectable)
    }

    private func verify(
        _ actualCount: Int,
        in store: HeadlessSimulationEntityStore
    ) throws(HeadlessSimulationError) {
        guard actualCount == configuration.entityCount else {
            throw .entityCountMismatch(
                store: store,
                expected: configuration.entityCount,
                actual: actualCount
            )
        }
    }

    private func referenceState(
        in world: World
    ) throws(HeadlessSimulationError) -> (
        entity: EntityID,
        initialPosition: SIMD3<Float>,
        initialVelocity: SIMD3<Float>,
        acceleration: SIMD3<Float>,
        initialRotation: simd_quatf,
        angularVelocity: SIMD3<Float>
    ) {
        guard
            let entity = world.positionComponents.entities.first,
            let initialPosition = world.positionComponents[entity]?.position,
            let initialMotion = world.motionComponents[entity],
            case let .accelerating(acceleration) = initialMotion.accelerationIntent,
            let initialRotation = world.rotationComponents[entity]?.rotation,
            let angularVelocity =
                world.angularVelocityComponents[entity]?.angularVelocity
        else {
            throw .invariantViolation("The headless world has no complete reference entity.")
        }

        return (
            entity,
            initialPosition,
            initialMotion.velocity,
            acceleration,
            initialRotation,
            angularVelocity
        )
    }

    private func verifyFirstTickProgress(
        in world: World,
        from initialState: (
            entity: EntityID,
            initialPosition: SIMD3<Float>,
            initialVelocity: SIMD3<Float>,
            acceleration: SIMD3<Float>,
            initialRotation: simd_quatf,
            angularVelocity: SIMD3<Float>
        )
    ) throws(HeadlessSimulationError) {
        guard
            let position = world.positionComponents[initialState.entity]?.position,
            position.isFinite,
            position != initialState.initialPosition,
            let velocity = world.motionComponents[initialState.entity]?.velocity,
            velocity.isFinite,
            velocity != initialState.initialVelocity,
            let rotation = world.rotationComponents[initialState.entity]?.rotation,
            rotation.vector.isFinite,
            rotation.vector != initialState.initialRotation.vector
        else {
            throw .invariantViolation(
                "The reference entity did not make finite translational and rotational progress."
            )
        }
    }

    private func verifyFinalState(
        in world: World,
        latestPresentation: SimulationPresentationSnapshot,
        initialReferenceState: (
            entity: EntityID,
            initialPosition: SIMD3<Float>,
            initialVelocity: SIMD3<Float>,
            acceleration: SIMD3<Float>,
            initialRotation: simd_quatf,
            angularVelocity: SIMD3<Float>
        ),
        worldBuilder: HeadlessSimulationWorldBuilder,
        finalCursor: SimulationCursor
    ) throws(HeadlessSimulationError) -> (
        firstPosition: SIMD3<Float>,
        lastPosition: SIMD3<Float>,
        firstRotation: simd_quatf
    ) {
        try verifyEntityCounts(in: world)
        guard latestPresentation.cursor == finalCursor else {
            throw .invariantViolation("The latest presentation does not identify the final headless cursor.")
        }
        guard latestPresentation.entityPresentations.count == configuration.entityCount else {
            throw .invariantViolation(
                "The final presentation contains \(latestPresentation.entityPresentations.count) entities; "
                + "expected \(configuration.entityCount)."
            )
        }
        let expectedReferenceState = expectedReferenceState(
            from: initialReferenceState,
            completedTickCount: finalCursor.tick.rawValue
        )
        guard
            let finalPosition = world.positionComponents[initialReferenceState.entity]?.position,
            finalPosition.isFinite,
            finalPosition == expectedReferenceState.position,
            let finalMotion = world.motionComponents[initialReferenceState.entity],
            finalMotion.velocity.isFinite,
            finalMotion.velocity == expectedReferenceState.velocity
        else {
            throw .invariantViolation("The reference entity has invalid final translational state.")
        }
        guard
            let finalRotation = world.rotationComponents[initialReferenceState.entity]?.rotation,
            finalRotation.vector.isFinite,
            abs(simd_length(finalRotation.vector) - 1) < 0.0001,
            abs(
                abs(simd_dot(finalRotation.vector, expectedReferenceState.rotation.vector)) - 1
            ) < 0.0001
        else {
            throw .invariantViolation("The reference entity has invalid final rotational state.")
        }

        for entityIndex in 0..<configuration.entityCount {
            let presentation = latestPresentation.entityPresentations[entityIndex]
            guard presentation.id.index == entityIndex, presentation.id.generation == 0 else {
                throw .invariantViolation(
                    "Presentation row \(entityIndex) identifies the unexpected entity \(presentation.id)."
                )
            }
            guard
                let position = world.positionComponents[presentation.id]?.position,
                let motion = world.motionComponents[presentation.id],
                let rotation = world.rotationComponents[presentation.id]?.rotation,
                let angularAccumulator =
                    world.angularMotionAccumulatorComponents[presentation.id]
            else {
                throw .invariantViolation(
                    "Entity \(presentation.id) has incomplete authoritative motion state."
                )
            }

            let initialPosition = worldBuilder.initialPosition(
                forEntityAt: entityIndex
            )
            let expectedPosition = expectedPosition(
                from: initialPosition,
                initialVelocity: initialReferenceState.initialVelocity,
                acceleration: initialReferenceState.acceleration,
                completedTickCount: finalCursor.tick.rawValue
            )
            guard position.isFinite,
                  position == expectedPosition,
                  motion.velocity == expectedReferenceState.velocity,
                  motion.accumulator == .zero
            else {
                throw .invariantViolation(
                    "Entity \(presentation.id) did not receive the complete headless motion."
                )
            }
            guard rotation.vector.isFinite,
                  abs(simd_length(rotation.vector) - 1) < 0.0001,
                  abs(
                      abs(
                          simd_dot(
                              rotation.vector,
                              expectedReferenceState.rotation.vector
                          )
                      ) - 1
                  ) < 0.0001,
                  angularAccumulator.angularAcceleration == .zero,
                  angularAccumulator.angularImpulse == .zero
            else {
                throw .invariantViolation(
                    "Entity \(presentation.id) did not receive the complete headless rotation."
                )
            }
            guard presentation.position == position,
                  presentation.rotation?.vector == rotation.vector,
                  presentation.meshID == .ball,
                  presentation.materialID == .warmDielectric
            else {
                throw .invariantViolation(
                    "Presentation row \(entityIndex) does not match authoritative entity state."
                )
            }
        }

        guard
            let lastEntity = world.positionComponents.entities.last,
            let lastPosition = world.positionComponents[lastEntity]?.position
        else {
            throw .invariantViolation("The headless world has no final positioned entity.")
        }

        return (finalPosition, lastPosition, finalRotation)
    }

    private func expectedReferenceState(
        from initialState: (
            entity: EntityID,
            initialPosition: SIMD3<Float>,
            initialVelocity: SIMD3<Float>,
            acceleration: SIMD3<Float>,
            initialRotation: simd_quatf,
            angularVelocity: SIMD3<Float>
        ),
        completedTickCount: UInt64
    ) -> (
        position: SIMD3<Float>,
        velocity: SIMD3<Float>,
        rotation: simd_quatf
    ) {
        let fixedTimeStep = SimulationRuntime.fixedTimeStep.seconds
        let angularStep = initialState.angularVelocity * fixedTimeStep
        let angularStepMagnitude = simd_length(angularStep)
        let rotationDelta: simd_quatf
        if angularStepMagnitude > 0 {
            rotationDelta = simd_quatf(
                angle: angularStepMagnitude,
                axis: angularStep / angularStepMagnitude
            )
        } else {
            rotationDelta = .identity
        }

        var velocity = initialState.initialVelocity
        var rotation = initialState.initialRotation
        for _ in 0..<completedTickCount {
            velocity += initialState.acceleration * fixedTimeStep
            let accumulatedRotation = rotationDelta * rotation
            rotation = simd_quatf(
                vector: simd_normalize(accumulatedRotation.vector)
            )
        }

        return (
            expectedPosition(
                from: initialState.initialPosition,
                initialVelocity: initialState.initialVelocity,
                acceleration: initialState.acceleration,
                completedTickCount: completedTickCount
            ),
            velocity,
            rotation
        )
    }

    private func expectedPosition(
        from initialPosition: SIMD3<Float>,
        initialVelocity: SIMD3<Float>,
        acceleration: SIMD3<Float>,
        completedTickCount: UInt64
    ) -> SIMD3<Float> {
        let fixedTimeStep = SimulationRuntime.fixedTimeStep.seconds
        var position = initialPosition
        var velocity = initialVelocity
        for _ in 0..<completedTickCount {
            velocity += acceleration * fixedTimeStep
            position += velocity * fixedTimeStep
        }
        return position
    }
}
