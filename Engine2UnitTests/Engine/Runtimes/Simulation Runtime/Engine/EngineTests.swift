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
        let snapshot = InputSnapshot(
            revision: InputRevision(session: 1, sequence: 1),
            translation: .zero,
            isInteractionActive: false,
            cameraOrbitTotal: SIMD2<Float>(0.4, 0),
            cameraZoomTotal: 1.2,
            latestSelectionPress: nil,
            selectionPressCount: 0
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
        #expect(world.input.cameraOrbitDelta == .zero)
        #expect(world.input.cameraZoomDelta == 0)

        engine.step()

        #expect(world.camera == cameraAfterInput)
        #expect(engine.completedTick == SimulationTick(rawValue: 2))
    }

    @Test func malformedSemanticInputCannotPoisonCamera() {
        let world = World()
        let initialCamera = world.camera
        let engine = Engine(
            world: world,
            fixedTimeStep: SimulationRuntime.fixedTimeStep,
            configuration: .basicGame
        )
        let snapshot = InputSnapshot(
            revision: InputRevision(session: 1, sequence: 1),
            translation: .zero,
            isInteractionActive: false,
            cameraOrbitTotal: SIMD2<Float>(.nan, .infinity),
            cameraZoomTotal: -.infinity,
            latestSelectionPress: nil,
            selectionPressCount: 0
        )

        engine.step(inputSnapshot: snapshot)

        #expect(world.camera == initialCamera)
        #expect(world.input.cameraOrbitDelta == .zero)
        #expect(world.input.cameraZoomDelta == 0)
        #expect(engine.completedTick == SimulationTick(rawValue: 1))
    }

    @Test func exactStepUsesTheInjectedSystemTestDuration() throws {
        let world = World()
        let entity = EntityID(index: 0, generation: 0)
        var motion = MotionComponent(
            velocity: SIMD3<Double>(4, 5, 6),
            impulse: SIMD3<Double>(1, -1, 0.5)
        )
        motion.accumulator.acceleration = SIMD3<Double>(2, 0, -2)

        let initialPosition = PositionComponent(position: SIMD3<Double>(1, 2, 3))
        world.positionComponents.insert(
            initialPosition,
            for: entity
        )
        world.motionComponents.insert(motion, for: entity)
        let engine = Engine(
            world: world,
            fixedTimeStep: .milliseconds(500),
            systems: [MovementSystem()]
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

    @Test func transientInputIsClearedAfterItsAttributedStep() {
        let world = World()
        let engine = Engine(
            world: world,
            fixedTimeStep: SimulationRuntime.fixedTimeStep,
            systems: [InputCleanupSystem()]
        )
        let snapshot = InputSnapshot(
            revision: InputRevision(session: 1, sequence: 1),
            translation: .zero,
            isInteractionActive: false,
            cameraOrbitTotal: SIMD2<Float>(3, -2),
            cameraZoomTotal: 0,
            latestSelectionPress: nil,
            selectionPressCount: 0
        )

        engine.step(inputSnapshot: snapshot)
        engine.step()

        #expect(world.input.cameraOrbitDelta == .zero)
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
        let baseline = InputSnapshot(
            revision: InputRevision(session: 2, sequence: 10),
            translation: SIMD2<Float>(1, 0),
            isInteractionActive: true,
            cameraOrbitTotal: SIMD2<Float>(1, 0),
            cameraZoomTotal: 1.6,
            latestSelectionPress: nil,
            selectionPressCount: 0
        )

        engine.replaceWorld(with: replacement, inputBaseline: baseline)

        #expect(engine.completedTick == .zero)
        #expect(replacement.input.translation == SIMD2<Float>(1, 0))
        #expect(replacement.input.isInteractionActive)
        #expect(replacement.input.cameraOrbitDelta == .zero)
        #expect(replacement.input.cameraZoomDelta == 0)
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
            translation: .zero,
            isInteractionActive: false,
            cameraOrbitTotal: SIMD2<Float>(1, 0),
            cameraZoomTotal: 0,
            latestSelectionPress: nil,
            selectionPressCount: 0
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
            translation: .zero,
            isInteractionActive: false,
            cameraOrbitTotal: SIMD2<Float>(0.1, 0),
            cameraZoomTotal: 0,
            latestSelectionPress: nil,
            selectionPressCount: 0
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

    @Test func completeInjectedScheduleRunsInOrder() {
        let recorder = ExecutionRecorder()
        let engine = Engine(
            world: World(),
            fixedTimeStep: SimulationRuntime.fixedTimeStep,
            systems: [
                RecordingSystem(name: "foundation", recorder: recorder),
                RecordingSystem(name: "extension", recorder: recorder),
            ]
        )

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

    private struct RecordingSystem: System {
        let name: String
        let recorder: ExecutionRecorder

        mutating func update(world: inout World, deltaTime: Double) {
            recorder.entries.append(name)
        }
    }
}
