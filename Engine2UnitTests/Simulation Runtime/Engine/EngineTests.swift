import Foundation
import simd
import Testing
@testable import Engine2

struct EngineTests {
    @Test func canonicalRuntimeStepIsPositiveAndFinite() {
        #expect(SimulationRuntime.fixedTimeStep > .zero)
        #expect(SimulationRuntime.fixedTimeStep.seconds.isFinite)
    }

    @Test func productionScheduleAppliesConfiguredCameraInputBeforeTransientCleanup() {
        let world = World()
        let initialCamera = world.camera
        let engine = Engine(
            world: world,
            fixedTimeStep: SimulationRuntime.fixedTimeStep,
            configuration: .basicGame
        )
        let snapshot = InputSnapshot(
            revision: InputRevision(session: 1, sequence: 1),
            pointerPosition: .zero,
            pointerMotionTotal: SIMD2<Float>(40, 0),
            scrollTotal: SIMD2<Float>(0, 30),
            pressedMouseButtons: [],
            pressedKeys: []
        )

        engine.step(inputSnapshot: snapshot)

        let cameraAfterInput = world.camera
        let expectedRadius: Float = 6.8
        let expectedPosition = SIMD3<Float>(
            sinf(0.4) * expectedRadius,
            0,
            cosf(0.4) * expectedRadius
        )
        #expect(cameraAfterInput != initialCamera)
        #expect(cameraAfterInput.position.isApproximately(expectedPosition))
        #expect(cameraAfterInput.projection == initialCamera.projection)
        #expect(world.inputHistory.entries.first?.tokens == [
            "Mouse dx:+40 dy:+0",
            "Wheel:+30"
        ])
        #expect(world.input.mouse.delta == .zero)
        #expect(world.input.mouse.scrollDelta == .zero)
        #expect(world.input.actions.cameraOrbitYawDelta == 0)
        #expect(world.input.actions.cameraZoomDelta == 0)

        engine.step()

        #expect(world.camera == cameraAfterInput)
        #expect(world.inputHistory.entries.count == 1)
        #expect(engine.completedTick == SimulationTick(rawValue: 2))
    }

    @Test func malformedRawInputCannotPoisonCameraOrCrashHistory() {
        let world = World()
        let initialCamera = world.camera
        let engine = Engine(
            world: world,
            fixedTimeStep: SimulationRuntime.fixedTimeStep,
            configuration: .basicGame
        )
        let pointerMotionTotal = SIMD2<Float>(.nan, .infinity)
        let scrollTotal = SIMD2<Float>(0, -.infinity)
        let snapshot = InputSnapshot(
            revision: InputRevision(session: 1, sequence: 1),
            pointerPosition: .zero,
            pointerMotionTotal: pointerMotionTotal,
            scrollTotal: scrollTotal,
            pressedMouseButtons: [],
            pressedKeys: []
        )

        engine.step(inputSnapshot: snapshot)

        #expect(world.camera == initialCamera)
        #expect(
            world.inputHistory.entries.first?.tokens == [
                "Mouse dx:+nan dy:+inf",
                "Wheel:-inf"
            ]
        )
        #expect(world.input.mouse.delta == .zero)
        #expect(world.input.mouse.scrollDelta == .zero)
        #expect(world.input.actions.cameraOrbitYawDelta == 0)
        #expect(world.input.actions.cameraZoomDelta == 0)
        #expect(engine.completedTick == SimulationTick(rawValue: 1))
    }

    @Test func exactStepUsesTheInjectedSystemTestDuration() throws {
        let world = World()
        let entity = EntityID(index: 0, generation: 0)
        var motion = CMotion(
            velocity: SIMD3<Double>(4, 5, 6),
            accelerationIntent: .idle,
            impulse: SIMD3<Double>(1, -1, 0.5)
        )
        motion.accumulator.acceleration = SIMD3<Double>(2, 0, -2)

        let initialPosition = CPosition(position: SIMD3<Double>(1, 2, 3))
        world.positionComponents.insert(
            initialPosition,
            for: entity
        )
        world.motionComponents.insert(motion, for: entity)
        let engine = Engine(
            world: world,
            fixedTimeStep: .milliseconds(500),
            systems: [SMovement()]
        )

        engine.step()

        #expect(
            world.motionComponents[entity]?.velocity == SIMD3<Double>(6, 4, 5.5)
        )
        #expect(
            world.positionComponents[entity]?.position == SIMD3<Double>(4, 4, 5.75)
        )
        #expect(engine.completedTick == SimulationTick(rawValue: 1))
    }

    @Test func productionScheduleLeavesGravityUninstalledUntilRefusalsHaveExpectedOutcomes() {
        let fixture = makeGravityFixture()
        let engine = Engine(
            world: fixture.world,
            fixedTimeStep: .seconds(1),
            configuration: .basicGame
        )

        engine.step()

        #expect(fixture.world.motionComponents[fixture.receiver]?.velocity == .zero)
        #expect(
            fixture.world.positionComponents[fixture.receiver]?.position
                == SIMD3<Double>(2, 0, 0)
        )
    }

    @Test func injectedGravityScheduleAppliesGravityBeforeMovement() {
        let fixture = makeGravityFixture()
        let engine = Engine(
            world: fixture.world,
            fixedTimeStep: .seconds(1),
            systems: [SGravity(), SMovement()]
        )

        engine.step()

        let expectedVelocity = SIMD3<Double>(-0.25, 0, 0)
        let expectedPosition = SIMD3<Double>(1.75, 0, 0)
        #expect(
            simd_distance(
                fixture.world.motionComponents[fixture.receiver]?.velocity ?? .zero,
                expectedVelocity
            ) < 1e-12
        )
        #expect(
            simd_distance(
                fixture.world.positionComponents[fixture.receiver]?.position ?? .zero,
                expectedPosition
            ) < 1e-12
        )
        #expect(fixture.world.motionComponents[fixture.receiver]?.accumulator == .zero)
        #expect(fixture.world.positionComponents[fixture.source]?.position == .zero)
    }

    @Test func eachStepRunsTheEntireScheduleInDeclarationOrder() {
        let recorder = ExecutionRecorder()
        let engine = Engine(
            world: World(),
            fixedTimeStep: SimulationRuntime.fixedTimeStep,
            systems: [
                RecordingSystem(name: "input", recorder: recorder),
                RecordingSystem(name: "simulation", recorder: recorder)
            ]
        )

        engine.step()

        #expect(recorder.entries == ["input", "simulation"])
        #expect(engine.completedTick == SimulationTick(rawValue: 1))
    }

    @Test func transientInputIsConsumedOnlyByItsAttributedStep() {
        let world = World()
        let engine = Engine(
            world: world,
            fixedTimeStep: SimulationRuntime.fixedTimeStep,
            systems: [SInputHistory(), SInputCleanup()]
        )
        let snapshot = InputSnapshot(
            revision: InputRevision(session: 1, sequence: 1),
            pointerPosition: .zero,
            pointerMotionTotal: SIMD2<Float>(3, -2),
            scrollTotal: .zero,
            pressedMouseButtons: [],
            pressedKeys: []
        )

        engine.step(inputSnapshot: snapshot)
        engine.step()

        #expect(world.inputHistory.entries.count == 1)
        #expect(world.inputHistory.entries.first?.tokens == ["Mouse dx:+3 dy:-2"])
        #expect(world.inputHistory.entries.first?.frameCount == 1)
        #expect(world.input.mouse.delta == .zero)
        #expect(engine.completedTick == SimulationTick(rawValue: 2))
    }

    @Test func replacingWorldStartsANewTimelineAndAppliesOnlyTheBaseline() {
        let engine = Engine(
            world: World(),
            fixedTimeStep: SimulationRuntime.fixedTimeStep,
            systems: []
        )
        engine.step()
        let replacement = World()
        let pointerPosition = SIMD2<Float>(8, 9)
        let baseline = InputSnapshot(
            revision: InputRevision(session: 2, sequence: 10),
            pointerPosition: pointerPosition,
            pointerMotionTotal: SIMD2<Float>(100, 0),
            scrollTotal: SIMD2<Float>(0, 40),
            pressedMouseButtons: [.right],
            pressedKeys: []
        )

        engine.replaceWorld(with: replacement, inputBaseline: baseline)

        #expect(engine.completedTick == .zero)
        #expect(replacement.input.mouse.position == pointerPosition)
        #expect(replacement.input.mouse.buttons == [.right])
        #expect(replacement.input.mouse.delta == .zero)
        #expect(replacement.input.mouse.scrollDelta == .zero)
    }

    @Test func cameraControlDerivesFromAReplacementWorldCamera() {
        let initialWorld = World()
        let engine = Engine(
            world: initialWorld,
            fixedTimeStep: SimulationRuntime.fixedTimeStep,
            configuration: .basicGame
        )
        let initialSnapshot = InputSnapshot(
            revision: InputRevision(session: 1, sequence: 1),
            pointerPosition: .zero,
            pointerMotionTotal: SIMD2<Float>(100, 0),
            scrollTotal: .zero,
            pressedMouseButtons: [],
            pressedKeys: []
        )
        engine.step(inputSnapshot: initialSnapshot)

        let replacement = World()
        let replacementProjection = Camera.Projection.orthographic(
            height: 12,
            near: 0.5,
            far: 200
        )
        replacement.camera = Camera.lookingAt(
            .zero,
            from: SIMD3<Float>(0, 3, 12),
            up: SIMD3<Float>(0, 1, 0),
            projection: replacementProjection
        )
        engine.replaceWorld(with: replacement, inputBaseline: nil)

        let replacementSnapshot = InputSnapshot(
            revision: InputRevision(session: 2, sequence: 1),
            pointerPosition: .zero,
            pointerMotionTotal: SIMD2<Float>(10, 0),
            scrollTotal: .zero,
            pressedMouseButtons: [],
            pressedKeys: []
        )
        engine.step(inputSnapshot: replacementSnapshot)

        let expectedPosition = SIMD3<Float>(
            sinf(0.1) * 12,
            3,
            cosf(0.1) * 12
        )
        #expect(replacement.camera.position.isApproximately(expectedPosition))
        #expect(replacement.camera.projection == replacementProjection)
    }

    @Test func appendedSystemsRunAfterTheFoundationalSchedule() {
        let recorder = ExecutionRecorder()
        let engine = Engine(
            world: World(),
            fixedTimeStep: SimulationRuntime.fixedTimeStep,
            systems: [RecordingSystem(name: "foundation", recorder: recorder)]
        )

        let extensionSystem = RecordingSystem(
            name: "extension",
            recorder: recorder
        )
        engine.addSystem(extensionSystem)
        engine.step()

        #expect(recorder.entries == ["foundation", "extension"])
    }
}

private extension SIMD3 where Scalar == Float {
    func isApproximately(_ other: SIMD3<Float>, tolerance: Float = 0.0001) -> Bool {
        abs(x - other.x) <= tolerance
            && abs(y - other.y) <= tolerance
            && abs(z - other.z) <= tolerance
    }
}

private extension EngineTests {
    func makeGravityFixture() -> (
        world: World,
        source: EntityID,
        receiver: EntityID
    ) {
        let source = EntityID(index: 0, generation: 0)
        let receiver = EntityID(index: 1, generation: 0)
        let gravitationalConstant = 6.67430e-11
        let world = World()
        world.positionComponents.insert(
            CPosition(position: .zero),
            for: source
        )
        world.massiveBodyComponents.insert(
            CMassiveBody(
                mass: AstronomicalMass(
                    kilograms: 1 / gravitationalConstant
                ),
                physicalRadius: AstronomicalDistance(meters: 0.1)
            ),
            for: source
        )
        world.positionComponents.insert(
            CPosition(position: SIMD3(2, 0, 0)),
            for: receiver
        )
        world.motionComponents.insert(CMotion.motionless, for: receiver)

        return (world, source, receiver)
    }

    private final class ExecutionRecorder {
        var entries: [String] = []
    }

    private struct RecordingSystem: PSystem {
        let name: String
        let recorder: ExecutionRecorder

        mutating func update(world: inout World, deltaTime: Double) {
            recorder.entries.append(name)
        }
    }
}
