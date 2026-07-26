import Foundation
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
        let revision = InputRevision(session: 1, sequence: 1)
        let snapshot = InputSnapshot(
            revision: revision,
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

        let expectedTick = SimulationTick(rawValue: 2)

        #expect(world.camera == cameraAfterInput)
        #expect(world.inputHistory.entries.count == 1)
        #expect(engine.completedTick == expectedTick)
    }

    @Test func malformedRawInputCannotPoisonCameraOrCrashHistory() {
        let world = World()
        let initialCamera = world.camera
        let engine = Engine(
            world: world,
            fixedTimeStep: SimulationRuntime.fixedTimeStep,
            configuration: .basicGame
        )
        let revision = InputRevision(session: 1, sequence: 1)
        let pointerMotionTotal = SIMD2<Float>(.nan, .infinity)
        let scrollTotal = SIMD2<Float>(0, -.infinity)
        let snapshot = InputSnapshot(
            revision: revision,
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
        let expectedTick = SimulationTick(rawValue: 1)
        #expect(engine.completedTick == expectedTick)
    }

    @Test func exactStepUsesTheInjectedSystemTestDuration() throws {
        let world = World()
        let entity = EntityID(index: 0, generation: 0)
        var motion = CMotion(
            velocity: SIMD3<Float>(4, 5, 6),
            impulse: SIMD3<Float>(1, -1, 0.5)
        )
        motion.accumulator.acceleration = SIMD3<Float>(2, 0, -2)

        let initialPosition = CPosition(position: SIMD3<Float>(1, 2, 3))
        world.positionComponents.insert(
            initialPosition,
            for: entity
        )
        world.motionComponents.insert(motion, for: entity)
        let systems: [any PSystem] = [SMovement()]
        let engine = Engine(
            world: world,
            fixedTimeStep: .milliseconds(500),
            systems: systems
        )

        engine.step()

        let expectedTick = SimulationTick(rawValue: 1)

        #expect(world.motionComponents[entity]?.velocity == SIMD3<Float>(6, 4, 5.5))
        #expect(world.positionComponents[entity]?.position == SIMD3<Float>(4, 4, 5.75))
        #expect(engine.completedTick == expectedTick)
    }

    @Test func eachStepRunsTheEntireScheduleInDeclarationOrder() {
        let recorder = ExecutionRecorder()
        let world = World()
        let systems: [any PSystem] = [
            RecordingSystem(name: "input", recorder: recorder),
            RecordingSystem(name: "simulation", recorder: recorder)
        ]
        let engine = Engine(
            world: world,
            fixedTimeStep: SimulationRuntime.fixedTimeStep,
            systems: systems
        )

        engine.step()

        let expectedTick = SimulationTick(rawValue: 1)
        #expect(recorder.entries == ["input", "simulation"])
        #expect(engine.completedTick == expectedTick)
    }

    @Test func transientInputIsConsumedOnlyByItsAttributedStep() {
        let world = World()
        let systems: [any PSystem] = [SInputHistory(), SInputCleanup()]
        let engine = Engine(
            world: world,
            fixedTimeStep: SimulationRuntime.fixedTimeStep,
            systems: systems
        )
        let revision = InputRevision(session: 1, sequence: 1)
        let snapshot = InputSnapshot(
            revision: revision,
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
        let expectedTick = SimulationTick(rawValue: 2)
        #expect(engine.completedTick == expectedTick)
    }

    @Test func replacingWorldStartsANewTimelineAndAppliesOnlyTheBaseline() {
        let initialWorld = World()
        let engine = Engine(
            world: initialWorld,
            fixedTimeStep: SimulationRuntime.fixedTimeStep,
            systems: []
        )
        engine.step()
        let replacement = World()
        let revision = InputRevision(session: 2, sequence: 10)
        let pointerPosition = SIMD2<Float>(8, 9)
        let baseline = InputSnapshot(
            revision: revision,
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
        let initialRevision = InputRevision(session: 1, sequence: 1)
        let initialSnapshot = InputSnapshot(
            revision: initialRevision,
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

        let replacementRevision = InputRevision(session: 2, sequence: 1)
        let replacementSnapshot = InputSnapshot(
            revision: replacementRevision,
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
        let world = World()
        let foundationalSystems: [any PSystem] = [
            RecordingSystem(name: "foundation", recorder: recorder)
        ]
        let engine = Engine(
            world: world,
            fixedTimeStep: SimulationRuntime.fixedTimeStep,
            systems: foundationalSystems
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
    private final class ExecutionRecorder {
        var entries: [String] = []
    }

    private struct RecordingSystem: PSystem {
        let name: String
        let recorder: ExecutionRecorder

        mutating func update(world: inout World, deltaTime: Float) {
            recorder.entries.append(name)
        }
    }
}
