import simd
import Testing
@testable import Engine2

struct SolarSystemWorldBuilderTests {
    private static let expectedEntityIDs = (0..<9).map {
        EntityID(index: $0, generation: 0)
    }

    /// Sun, Mercury, Venus, Earth, Mars, Jupiter, Saturn, Uranus, Neptune.
    private static let expectedMassesKilograms = [
        1.98847e30,
        3.30103e23,
        4.86731e24,
        5.97217e24,
        6.41691e23,
        1.898125e27,
        5.68317e26,
        8.68099e25,
        1.024092e26
    ]

    private static let expectedPhysicalRadiiMeters = [
        695_700_000.0,
        2_439_400.0,
        6_051_800.0,
        6_371_008.4,
        3_389_500.0,
        69_911_000.0,
        58_232_000.0,
        25_362_000.0,
        24_622_000.0
    ]

    @Test func buildsSunAndEightPlanetsInCanonicalOrder() {
        let world = SolarSystemWorldBuilder().buildWorld()

        #expect(world.positionComponents.entities == Self.expectedEntityIDs)
        #expect(world.motionComponents.entities == Self.expectedEntityIDs)
        #expect(world.scaleComponents.entities == Self.expectedEntityIDs)
        #expect(world.renderableComponents.entities == Self.expectedEntityIDs)
        #expect(world.massiveBodyComponents.entities == Self.expectedEntityIDs)

        #expect(world.positionComponents.dense.count == 9)
        #expect(world.motionComponents.dense.count == 9)
        #expect(world.scaleComponents.dense.count == 9)
        #expect(world.renderableComponents.dense.count == 9)
        #expect(world.massiveBodyComponents.dense.count == 9)

        #expect(world.rotationComponents.entities.isEmpty)
        #expect(world.angularVelocityComponents.entities.isEmpty)
        #expect(world.angularMotionAccumulatorComponents.entities.isEmpty)
        #expect(world.selectableComponents.entities.isEmpty)

        #expect(
            world.renderableComponents.dense.map(\.meshID) ==
                Array(repeating: MeshID.ball, count: 9)
        )
    }

    @Test func physicalFactsRemainIndependentOfSymbolicModelScale() {
        let world = SolarSystemWorldBuilder().buildWorld()

        #expect(
            world.massiveBodyComponents.dense.map { $0.mass.kilograms } ==
                Self.expectedMassesKilograms
        )
        #expect(
            world.massiveBodyComponents.dense.map {
                $0.physicalRadius.meters
            } == Self.expectedPhysicalRadiiMeters
        )

        for index in Self.expectedEntityIDs.indices {
            let scale = world.scaleComponents.dense[index].scale
            let physicalRadius = Self.expectedPhysicalRadiiMeters[index]

            #expect(scale.isFinite)
            #expect(scale.x > 0)
            #expect(scale.x == scale.y)
            #expect(scale.y == scale.z)
            #expect(Double(scale.x) > physicalRadius)
        }
    }

    @Test func rebuildingProducesTheSameAuthoritativeRows() {
        let first = SolarSystemWorldBuilder().buildWorld()
        let second = SolarSystemWorldBuilder().buildWorld()

        #expect(first.camera == second.camera)
        #expect(first.positionComponents.entities == second.positionComponents.entities)
        #expect(first.positionComponents.dense == second.positionComponents.dense)
        #expect(first.motionComponents.entities == second.motionComponents.entities)
        #expect(first.motionComponents.dense == second.motionComponents.dense)
        #expect(first.scaleComponents.entities == second.scaleComponents.entities)
        #expect(first.scaleComponents.dense == second.scaleComponents.dense)
        #expect(first.renderableComponents.entities == second.renderableComponents.entities)
        #expect(first.renderableComponents.dense == second.renderableComponents.dense)
        #expect(first.massiveBodyComponents.entities == second.massiveBodyComponents.entities)
        #expect(first.massiveBodyComponents.dense == second.massiveBodyComponents.dense)
    }

    @Test func publishesNineFiniteVisibleSphereInstances() {
        let world = SolarSystemWorldBuilder().buildWorld()
        let snapshot = world.presentationSnapshot(
            at: SimulationCursor(
                sessionID: SimulationSessionID(),
                tick: .zero
            )
        )
        let frame = RenderFrame(projecting: snapshot)

        #expect(frame.instances.count == 9)
        #expect(frame.instances.map(\.meshID) == Array(repeating: .ball, count: 9))

        guard case let .perspective(fieldOfView, near, far) = frame.camera.projection else {
            Issue.record("The Solar System reference camera must remain perspective.")
            return
        }
        #expect(fieldOfView == .pi / 3)
        #expect(near == 1.0e10)
        #expect(far == 4.0e13)

        let viewProjection = frame.camera.viewProjectionMatrix(aspectRatio: 1)
        let viewMatrix = frame.camera.viewMatrix
        for instance in frame.instances {
            let position = instance.transform.position
            let scale = instance.transform.scale
            let worldPosition = SIMD4<Float>(position, 1)
            let clipPosition = viewProjection * worldPosition
            let viewPosition = viewMatrix * worldPosition

            #expect(position.isFinite)
            #expect(scale.isFinite)
            #expect(clipPosition.isFinite)
            #expect(clipPosition.w > 0)

            let normalizedPosition = clipPosition / clipPosition.w
            #expect(abs(normalizedPosition.x) < 1)
            #expect(abs(normalizedPosition.y) < 1)
            #expect(normalizedPosition.z >= 0)
            #expect(normalizedPosition.z <= 1)

            let visibleHeight = 2 * abs(viewPosition.z) * tanf(fieldOfView / 2)
            #expect((2 * scale.x) / visibleHeight >= 0.004)
        }
    }

    @Test func gravityUsesPhysicalFactsWithoutMutatingPresentationState() throws {
        let world = SolarSystemWorldBuilder().buildWorld()
        let retainedPositions = world.positionComponents.dense
        let retainedMassiveBodies = world.massiveBodyComponents.dense
        let retainedScales = world.scaleComponents.dense

        try SGravity().accumulateGravity(in: world)

        let sunPosition = world.positionComponents.dense[0].position
        for index in world.motionComponents.dense.indices {
            let acceleration = world.motionComponents.dense[index]
                .accumulator.acceleration

            #expect(acceleration.isFinite)
            #expect(!acceleration.isZero)

            guard index > 0 else {
                continue
            }
            let directionToSun = sunPosition -
                world.positionComponents.dense[index].position
            #expect(simd_dot(acceleration, directionToSun) > 0)
        }

        #expect(world.positionComponents.dense == retainedPositions)
        #expect(world.massiveBodyComponents.dense == retainedMassiveBodies)
        #expect(world.scaleComponents.dense == retainedScales)
    }

    @Test func acceleratedProductionTickPublishesChangedFinitePositions() {
        let world = SolarSystemWorldBuilder().buildWorld()
        let sessionID = SimulationSessionID()
        let initialSnapshot = world.presentationSnapshot(
            at: SimulationCursor(sessionID: sessionID, tick: .zero)
        )
        let engine = Engine(
            world: world,
            fixedTimeStep: SimulationRuntime.fixedTimeStep,
            configuration: .solarSystem
        )

        engine.step()

        let advancedSnapshot = world.presentationSnapshot(
            at: SimulationCursor(
                sessionID: sessionID,
                tick: engine.completedTick
            )
        )
        let initialPositions = initialSnapshot.entityPresentations.compactMap(\.position)
        let advancedPositions = advancedSnapshot.entityPresentations.compactMap(\.position)

        #expect(advancedPositions.count == 9)
        #expect(advancedPositions.allSatisfy { $0.isFinite })
        for index in advancedPositions.indices {
            #expect(advancedPositions[index] != initialPositions[index])
        }
    }
}
