import simd
import Testing
@testable import Engine2

struct SGravityTests {
    private let gravitationalConstant = 6.67430e-11

    @Test func worldWithoutASourceLeavesReceiversUntouched() throws {
        let receiver = EntityID(index: 0, generation: 0)
        let retainedAcceleration = SIMD3<Double>(1, 2, 3)
        let world = World()
        insertMotion(
            acceleration: retainedAcceleration,
            for: receiver,
            in: world
        )

        let system = SGravity()
        try system.accumulateGravity(in: world)

        #expect(
            world.motionComponents[receiver]?.accumulator.acceleration
                == retainedAcceleration
        )
    }

    @Test func componentCompositionAddsOneCompletedReceiverBatch() throws {
        let sourceAndReceiver = EntityID(index: 10, generation: 0)
        let sourceOnly = EntityID(index: 20, generation: 0)
        let receiverOnly = EntityID(index: 30, generation: 0)
        let unitParameterMass = AstronomicalMass(
            kilograms: 1 / gravitationalConstant
        )
        let massiveBody = CMassiveBody(
            mass: unitParameterMass,
            physicalRadius: AstronomicalDistance(meters: 0.1)
        )
        let world = World()

        world.positionComponents.insert(
            CPosition(position: SIMD3(-2, 0, 0)),
            for: receiverOnly
        )
        world.positionComponents.insert(
            CPosition(position: SIMD3(2, 0, 0)),
            for: sourceOnly
        )
        world.positionComponents.insert(
            CPosition(position: .zero),
            for: sourceAndReceiver
        )
        world.massiveBodyComponents.insert(massiveBody, for: sourceOnly)
        world.massiveBodyComponents.insert(massiveBody, for: sourceAndReceiver)
        insertMotion(
            acceleration: SIMD3(1, 2, 3),
            for: receiverOnly,
            in: world
        )
        insertMotion(
            acceleration: SIMD3(-1, 0, 0),
            for: sourceAndReceiver,
            in: world
        )

        let system = SGravity()
        try system.accumulateGravity(in: world)

        expectEqual(
            world.motionComponents[receiverOnly]?.accumulator.acceleration,
            SIMD3(1.3125, 2, 3)
        )
        expectEqual(
            world.motionComponents[sourceAndReceiver]?.accumulator.acceleration,
            SIMD3(-0.75, 0, 0)
        )
        #expect(world.motionComponents[sourceOnly] == nil)
        #expect(world.positionComponents[receiverOnly]?.position == SIMD3(-2, 0, 0))
        #expect(world.positionComponents[sourceAndReceiver]?.position == .zero)
        #expect(world.positionComponents[sourceOnly]?.position == SIMD3(2, 0, 0))
    }

    @Test func contactFailureNamesEntitiesAndLeavesEveryAccumulatorUnchanged() {
        let first = EntityID(index: 2, generation: 0)
        let second = EntityID(index: 9, generation: 0)
        let massiveBody = CMassiveBody(
            mass: .earth,
            physicalRadius: AstronomicalDistance(meters: 1)
        )
        let world = World()

        world.positionComponents.insert(
            CPosition(position: SIMD3(1.5, 0, 0)),
            for: second
        )
        world.positionComponents.insert(
            CPosition(position: .zero),
            for: first
        )
        world.massiveBodyComponents.insert(massiveBody, for: second)
        world.massiveBodyComponents.insert(massiveBody, for: first)
        insertMotion(
            acceleration: SIMD3(1, 2, 3),
            for: second,
            in: world
        )
        insertMotion(
            acceleration: SIMD3(4, 5, 6),
            for: first,
            in: world
        )
        let retainedFirstMotion = world.motionComponents[first]
        let retainedSecondMotion = world.motionComponents[second]

        let system = SGravity()
        #expect(
            throws: GravitySystemError.contact(
                firstEntity: first,
                secondEntity: second
            )
        ) {
            try system.accumulateGravity(in: world)
        }

        #expect(world.motionComponents[first] == retainedFirstMotion)
        #expect(world.motionComponents[second] == retainedSecondMotion)
    }

    @Test func correctedNumericFailureCanRetryWithoutAPartialCommit() throws {
        let first = EntityID(index: 2, generation: 0)
        let second = EntityID(index: 9, generation: 0)
        let massiveBody = CMassiveBody(
            mass: .earth,
            physicalRadius: AstronomicalDistance(meters: 1)
        )
        let world = World()

        world.positionComponents.insert(
            CPosition(position: SIMD3(-Double.greatestFiniteMagnitude, 0, 0)),
            for: first
        )
        world.positionComponents.insert(
            CPosition(position: SIMD3(Double.greatestFiniteMagnitude, 0, 0)),
            for: second
        )
        world.massiveBodyComponents.insert(massiveBody, for: first)
        world.massiveBodyComponents.insert(massiveBody, for: second)
        insertMotion(
            acceleration: SIMD3(1, 2, 3),
            for: first,
            in: world
        )
        insertMotion(
            acceleration: SIMD3(4, 5, 6),
            for: second,
            in: world
        )
        let retainedFirstMotion = world.motionComponents[first]
        let retainedSecondMotion = world.motionComponents[second]

        let system = SGravity()
        #expect(
            throws: GravitySystemError.unrepresentableInteraction(
                firstEntity: first,
                secondEntity: second
            )
        ) {
            try system.accumulateGravity(in: world)
        }
        #expect(world.motionComponents[first] == retainedFirstMotion)
        #expect(world.motionComponents[second] == retainedSecondMotion)

        let didCorrectFirst = world.positionComponents.update(for: first) {
            $0.position = .zero
        }
        let didCorrectSecond = world.positionComponents.update(for: second) {
            $0.position = SIMD3(3, 0, 0)
        }
        #expect(didCorrectFirst)
        #expect(didCorrectSecond)

        try system.accumulateGravity(in: world)

        #expect(world.motionComponents[first] != retainedFirstMotion)
        #expect(world.motionComponents[second] != retainedSecondMotion)
    }

    @Test func accumulatorFailureLeavesEarlierReceiversUnchanged() {
        let firstReceiver = EntityID(index: 0, generation: 0)
        let invalidReceiver = EntityID(index: 1, generation: 0)
        let source = EntityID(index: 2, generation: 0)
        let world = World()

        world.positionComponents.insert(
            CPosition(position: .zero),
            for: firstReceiver
        )
        world.positionComponents.insert(
            CPosition(position: SIMD3(5, 0, 0)),
            for: invalidReceiver
        )
        world.positionComponents.insert(
            CPosition(position: SIMD3(10, 0, 0)),
            for: source
        )
        world.massiveBodyComponents.insert(
            CMassiveBody(
                mass: .earth,
                physicalRadius: AstronomicalDistance(meters: 0.1)
            ),
            for: source
        )
        insertMotion(
            acceleration: SIMD3(1, 2, 3),
            for: firstReceiver,
            in: world
        )
        insertMotion(
            acceleration: SIMD3(.infinity, 5, 6),
            for: invalidReceiver,
            in: world
        )
        let retainedFirstMotion = world.motionComponents[firstReceiver]
        let retainedInvalidMotion = world.motionComponents[invalidReceiver]

        let system = SGravity()
        #expect(
            throws: GravitySystemError.unrepresentableAccumulator(
                entity: invalidReceiver
            )
        ) {
            try system.accumulateGravity(in: world)
        }

        #expect(world.motionComponents[firstReceiver] == retainedFirstMotion)
        #expect(world.motionComponents[invalidReceiver] == retainedInvalidMotion)
    }

    private func insertMotion(
        acceleration: SIMD3<Double>,
        for entity: EntityID,
        in world: World
    ) {
        var motion = CMotion.motionless
        motion.accumulator.acceleration = acceleration
        world.motionComponents.insert(motion, for: entity)
    }

    private func expectEqual(
        _ actual: SIMD3<Double>?,
        _ expected: SIMD3<Double>
    ) {
        guard let actual else {
            Issue.record("Expected a motion acceleration for the receiver.")
            return
        }
        #expect(simd_distance(actual, expected) < 1e-12)
    }
}
