import Testing
@testable import Engine2

struct EngineTests {
    @Test func canonicalRuntimeStepIsPositiveAndFinite() {
        #expect(SimulationRuntime.fixedTimeStep > .zero)
        #expect(SimulationRuntime.fixedTimeStep.seconds.isFinite)
    }

    @Test func defaultScheduleRecordsInputWithoutMutatingTheSimulationCamera() {
        let world = World()
        let initialCamera = world.camera
        let engine = Engine(
            world: world,
            fixedTimeStep: SimulationRuntime.fixedTimeStep
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

        #expect(world.camera == initialCamera)
        #expect(world.input.history.first?.tokens == [
            "Mouse dx:+40 dy:+0",
            "Wheel:+30"
        ])
        #expect(world.input.mouse.delta == .zero)
        #expect(world.input.mouse.scrollDelta == .zero)
        #expect(engine.completedTick == SimulationTick(rawValue: 1))
    }

    @Test func exactStepUsesTheInjectedSystemTestDuration() throws {
        let world = World()
        let entity = EntityID(index: 0, generation: 0)
        var motion = CMotion(
            velocity: SIMD3<Float>(4, 5, 6),
            impulse: SIMD3<Float>(1, -1, 0.5)
        )
        motion.accumulator.acceleration = SIMD3<Float>(2, 0, -2)

        world.positionComponents.insert(
            CPosition(position: SIMD3<Float>(1, 2, 3)),
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
            world.motionComponents[entity]?.velocity ==
            SIMD3<Float>(6, 4, 5.5)
        )
        #expect(
            world.positionComponents[entity]?.position ==
            SIMD3<Float>(4, 4, 5.75)
        )
        #expect(engine.completedTick == SimulationTick(rawValue: 1))
    }

    @Test func eachStepRunsTheEntireScheduleInDeclarationOrder() {
        let recorder = ExecutionRecorder()
        let engine = Engine(
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

        #expect(world.input.history.count == 1)
        #expect(world.input.history.first?.tokens == ["Mouse dx:+3 dy:-2"])
        #expect(world.input.history.first?.frameCount == 1)
        #expect(world.input.mouse.delta == .zero)
        #expect(engine.completedTick == SimulationTick(rawValue: 2))
    }

    @Test func replacingWorldStartsANewTimelineAndAppliesOnlyTheBaseline() {
        let engine = Engine(
            fixedTimeStep: SimulationRuntime.fixedTimeStep,
            systems: []
        )
        engine.step()
        let replacement = World()
        let baseline = InputSnapshot(
            revision: InputRevision(session: 2, sequence: 10),
            pointerPosition: SIMD2<Float>(8, 9),
            pointerMotionTotal: SIMD2<Float>(100, 0),
            scrollTotal: SIMD2<Float>(0, 40),
            pressedMouseButtons: [.right],
            pressedKeys: []
        )

        engine.replaceWorld(with: replacement, inputBaseline: baseline)

        #expect(engine.completedTick == .zero)
        #expect(replacement.input.mouse.position == SIMD2<Float>(8, 9))
        #expect(replacement.input.mouse.buttons == [.right])
        #expect(replacement.input.mouse.delta == .zero)
        #expect(replacement.input.mouse.scrollDelta == .zero)
    }

    @Test func appendedSystemsRunAfterTheFoundationalSchedule() {
        let recorder = ExecutionRecorder()
        let engine = Engine(
            fixedTimeStep: SimulationRuntime.fixedTimeStep,
            systems: [RecordingSystem(name: "foundation", recorder: recorder)]
        )

        engine.addSystem(
            RecordingSystem(name: "extension", recorder: recorder)
        )
        engine.step()

        #expect(recorder.entries == ["foundation", "extension"])
    }
}

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
