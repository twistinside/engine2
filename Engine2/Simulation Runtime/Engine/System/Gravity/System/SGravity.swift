import simd

/// Adds one collective Newtonian gravity evaluation to motion accumulators.
///
/// Every `CPosition` and `CMassiveBody` row pair is a source. Every
/// `CPosition` and `CMotion` row pair is a receiver. The system snapshots and
/// validates the complete union, evaluates it without ECS mutation, then adds
/// every completed receiver contribution as one commit phase. It does not
/// integrate velocity or position and does not clear existing contributions.
struct SGravity: PSystem {
    private let evaluator = NewtonianGravityEvaluator()

    mutating func update(world: inout World, deltaTime _: Double) {
        do {
            try accumulateGravity(in: world)
        } catch {
            preconditionFailure(
                "The scheduled gravity system rejected its World state: \(error)"
            )
        }
    }

    /// Calculates and commits one complete acceleration batch.
    ///
    /// A typed refusal leaves every motion accumulator unchanged. The method
    /// exists separately from `PSystem.update` so focused callers can handle
    /// contact and numeric failures before the scheduler gains a collision lane.
    func accumulateGravity(
        in world: World
    ) throws(GravitySystemError) {
        let entities = orderedParticipantEntities(in: world)
        guard !entities.isEmpty else {
            return
        }
        let participants = makeParticipants(
            for: entities,
            in: world
        )
        let gravityAccelerations: [SIMD3<Double>]
        do {
            gravityAccelerations = try evaluator.accelerations(for: participants)
        } catch {
            throw systemError(
                for: error,
                participantEntities: entities
            )
        }
        let completedAccelerations = try makeCompletedAccelerations(
            for: entities,
            adding: gravityAccelerations,
            in: world
        )
        commit(
            completedAccelerations,
            for: entities,
            to: world
        )
    }

    private func orderedParticipantEntities(in world: World) -> [EntityID] {
        let sourceEntities = world.massiveBodyComponents.entities.filter {
            world.positionComponents[$0] != nil
        }
        guard !sourceEntities.isEmpty else {
            return []
        }
        let receiverEntities = world.motionComponents.entities.filter {
            world.positionComponents[$0] != nil
        }
        let entities = Set(sourceEntities + receiverEntities)
        return entities.sorted { first, second in
            if first.index == second.index {
                return first.generation < second.generation
            }
            return first.index < second.index
        }
    }

    private func makeParticipants(
        for entities: [EntityID],
        in world: World
    ) -> [NewtonianGravityParticipant] {
        var participants: [NewtonianGravityParticipant] = []
        participants.reserveCapacity(entities.count)

        for entity in entities {
            guard let position = world.positionComponents[entity] else {
                preconditionFailure(
                    "A selected gravity participant must retain its position through the synchronous snapshot."
                )
            }
            let massiveBody = world.massiveBodyComponents[entity]
            participants.append(
                NewtonianGravityParticipant(
                    sourceMass: massiveBody?.mass,
                    physicalRadius: massiveBody?.physicalRadius ?? .zero,
                    positionMeters: position.position,
                    receivesGravity: world.motionComponents[entity] != nil
                )
            )
        }

        return participants
    }

    private func systemError(
        for evaluationError: NewtonianGravityEvaluationError,
        participantEntities: [EntityID]
    ) -> GravitySystemError {
        switch evaluationError {
        case let .invalidSourceMass(bodyIndex):
            .invalidSourceMass(entity: participantEntities[bodyIndex])
        case let .invalidPhysicalRadius(bodyIndex):
            .invalidPhysicalRadius(entity: participantEntities[bodyIndex])
        case let .invalidPosition(bodyIndex):
            .invalidPosition(entity: participantEntities[bodyIndex])
        case let .unrepresentableGravitationalParameter(bodyIndex):
            .unrepresentableGravitationalParameter(
                entity: participantEntities[bodyIndex]
            )
        case let .contact(firstBodyIndex, secondBodyIndex):
            .contact(
                firstEntity: participantEntities[firstBodyIndex],
                secondEntity: participantEntities[secondBodyIndex]
            )
        case let .unrepresentableInteraction(firstBodyIndex, secondBodyIndex):
            .unrepresentableInteraction(
                firstEntity: participantEntities[firstBodyIndex],
                secondEntity: participantEntities[secondBodyIndex]
            )
        case let .unrepresentableAcceleration(bodyIndex):
            .unrepresentableAcceleration(
                entity: participantEntities[bodyIndex]
            )
        }
    }

    private func makeCompletedAccelerations(
        for entities: [EntityID],
        adding gravityAccelerations: [SIMD3<Double>],
        in world: World
    ) throws(GravitySystemError) -> [SIMD3<Double>?] {
        var completedAccelerations = Array<SIMD3<Double>?>(
            repeating: nil,
            count: entities.count
        )

        for index in entities.indices {
            let entity = entities[index]
            guard let motion = world.motionComponents[entity] else {
                continue
            }
            let completedAcceleration = motion.accumulator.acceleration
                + gravityAccelerations[index]
            guard completedAcceleration.isFinite else {
                throw .unrepresentableAccumulator(entity: entity)
            }
            completedAccelerations[index] = completedAcceleration
        }

        return completedAccelerations
    }

    private func commit(
        _ completedAccelerations: [SIMD3<Double>?],
        for entities: [EntityID],
        to world: World
    ) {
        for index in entities.indices {
            guard let completedAcceleration = completedAccelerations[index] else {
                continue
            }
            let didUpdate = world.motionComponents.update(for: entities[index]) { motion in
                motion.accumulator.acceleration = completedAcceleration
            }
            precondition(
                didUpdate,
                "A validated gravity receiver must retain its motion row through the synchronous commit."
            )
        }
    }
}
