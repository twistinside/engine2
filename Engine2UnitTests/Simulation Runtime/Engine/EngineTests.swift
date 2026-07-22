import Testing
@testable import Engine2

struct EngineTests {
    @Test func defaultFixedTimeStepIsPositive() async throws {
        let engine = Engine()

        #expect(engine.fixedTimeStep > .zero)
    }

    @Test func defaultScheduleRecordsInputWithoutMutatingTheSimulationCamera() {
        let world = World()
        let initialCamera = world.camera
        let engine = Engine(world: world, systems: [])
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
    }

    @Test func updateAccumulatesTimeUntilFixedStepBoundary() async throws {
        let world = World()
        let entity = EntityID(index: 0, generation: 0)
        var motion = CMotion(
            velocity: SIMD3<Float>(4, 5, 6),
            impulse: SIMD3<Float>(1, -1, 0.5)
        )
        motion.accumulator.acceleration = SIMD3<Float>(2, 0, -2)

        world.positionComponents.insert(CPosition(position: SIMD3<Float>(1, 2, 3)), for: entity)
        world.motionComponents.insert(motion, for: entity)

        let engine = Engine(world: world, fixedTimeStep: .milliseconds(500), systems: [SMovement()])

        engine.update(deltaTime: .milliseconds(490))

        #expect(world.motionComponents[entity]?.velocity == SIMD3<Float>(4, 5, 6))
        #expect(world.positionComponents[entity]?.position == SIMD3<Float>(1, 2, 3))
        #expect(engine.accumulatedTime == .milliseconds(490))
        #expect(engine.completedTick == .zero)

        engine.update(deltaTime: .milliseconds(10))

        #expect(world.motionComponents[entity]?.velocity == SIMD3<Float>(6, 4, 5.5))
        #expect(world.positionComponents[entity]?.position == SIMD3<Float>(4, 4, 5.75))
        #expect(engine.accumulatedTime == .zero)
        #expect(engine.completedTick == SimulationTick(rawValue: 1))
    }

    @Test func legacyPausedUpdateRunsAlwaysSystemsButSkipsSimulationSystems() async throws {
        let world = World()
        let entity = EntityID(index: 0, generation: 0)

        world.positionComponents.insert(CPosition(position: .zero), for: entity)
        world.motionComponents.insert(
            CMotion(velocity: SIMD3<Float>(10, 0, 0)),
            for: entity
        )
        let engine = Engine(
            world: world,
            fixedTimeStep: .milliseconds(100),
            alwaysSystems: [SInputHistory(), SInputCleanup()],
            systems: [SMovement()]
        )
        engine.isSimulationRunning = false

        engine.update(
            deltaTime: .milliseconds(100),
            inputSnapshot: inputSnapshot(
                sequence: 1,
                pressedMouseButtons: [.left]
            )
        )

        #expect(world.positionComponents[entity]?.position == .zero)
        #expect(world.input.history.count == 1)
        #expect(world.input.history[0].tokens == ["LMB"])
        #expect(engine.accumulatedTime == .zero)
        #expect(engine.completedTick == SimulationTick(rawValue: 1))
    }

    @Test func exactStepRunsCompleteScheduleWhileLegacyRealtimeGateIsPaused() {
        let recorder = ExecutionRecorder()
        let engine = Engine(
            alwaysSystems: [RecordingSystem(name: "always", recorder: recorder)],
            systems: [RecordingSystem(name: "simulation", recorder: recorder)]
        )
        engine.isSimulationRunning = false

        engine.step()

        #expect(recorder.entries == ["always", "simulation"])
        #expect(engine.completedTick == SimulationTick(rawValue: 1))
    }

    @Test func exactStepDoesNotConsumeInputPendingFromLegacyElapsedTime() {
        let world = World()
        let engine = Engine(
            world: world,
            fixedTimeStep: .seconds(1),
            systems: []
        )
        let key = KeyboardKey(keyCode: 13, displayName: "W")
        let pendingSnapshot = InputSnapshot(
            revision: InputRevision(session: 1, sequence: 1),
            pointerPosition: .zero,
            pointerMotionTotal: SIMD2<Float>(4, 2),
            scrollTotal: .zero,
            pressedMouseButtons: [],
            pressedKeys: [key]
        )
        engine.update(
            deltaTime: .milliseconds(500),
            inputSnapshot: pendingSnapshot
        )

        engine.step()

        #expect(world.input.keyboard.keys.isEmpty)
        #expect(world.input.history.isEmpty)
        #expect(engine.completedTick == SimulationTick(rawValue: 1))
    }

    @Test func updateRunsMultipleFixedStepsAndRetainsRemainder() {
        let world = World()
        let engine = Engine(
            world: world,
            fixedTimeStep: .milliseconds(100),
            alwaysSystems: [],
            systems: [StatefulSystem()]
        )

        engine.update(deltaTime: .milliseconds(250))

        #expect(world.camera.position.x == 2)
        #expect(engine.accumulatedTime == .milliseconds(50))
        #expect(engine.completedTick == SimulationTick(rawValue: 2))
    }

    @Test func updateRetainsInputUntilAFixedStepRuns() {
        let world = World()
        let engine = Engine(
            world: world,
            fixedTimeStep: .milliseconds(100),
            alwaysSystems: [],
            systems: []
        )

        engine.update(
            deltaTime: .milliseconds(40),
            inputSnapshot: inputSnapshot(
                sequence: 1,
                pointerMotionTotal: SIMD2<Float>(3, -2)
            )
        )

        #expect(world.input.mouse.delta == .zero)

        engine.update(deltaTime: .milliseconds(60))

        #expect(world.input.mouse.delta == SIMD2<Float>(3, -2))
    }

    @Test func catchUpUpdateConsumesTransientInputOnlyOnce() {
        let world = World()
        let engine = Engine(
            world: world,
            fixedTimeStep: .milliseconds(100),
            alwaysSystems: [InputDeltaAccumulatorSystem(), SInputCleanup()],
            systems: []
        )

        engine.update(
            deltaTime: .milliseconds(250),
            inputSnapshot: inputSnapshot(
                sequence: 1,
                pointerMotionTotal: SIMD2<Float>(4, 0)
            )
        )

        #expect(world.camera.position.x == 4)
        #expect(engine.completedTick == SimulationTick(rawValue: 2))
        #expect(world.input.mouse.delta == .zero)
    }

    @Test func pendingInputKeepsNewestRevisionAcrossSubstepPolls() {
        let world = World()
        let engine = Engine(
            world: world,
            fixedTimeStep: .milliseconds(100),
            alwaysSystems: [],
            systems: []
        )

        engine.update(
            deltaTime: .milliseconds(40),
            inputSnapshot: inputSnapshot(
                sequence: 5,
                pointerMotionTotal: SIMD2<Float>(5, 0)
            )
        )
        engine.update(
            deltaTime: .milliseconds(40),
            inputSnapshot: inputSnapshot(
                sequence: 4,
                pointerMotionTotal: SIMD2<Float>(99, 0)
            )
        )
        engine.update(deltaTime: .milliseconds(20))

        #expect(world.input.mouse.delta == SIMD2<Float>(5, 0))
        #expect(engine.completedTick == SimulationTick(rawValue: 1))
    }

    @Test func replacingWorldClearsPendingInputAndRebasesToExplicitBaseline() {
        let engine = Engine(
            fixedTimeStep: .milliseconds(100),
            alwaysSystems: [],
            systems: []
        )
        engine.update(
            deltaTime: .milliseconds(50),
            inputSnapshot: inputSnapshot(
                session: 3,
                sequence: 1,
                pointerMotionTotal: SIMD2<Float>(4, 0),
                pressedMouseButtons: [.left]
            )
        )
        let replacement = World()
        let baseline = inputSnapshot(
            session: 2,
            sequence: 10,
            pointerMotionTotal: SIMD2<Float>(100, 0),
            pressedMouseButtons: [.right]
        )

        engine.replaceWorld(with: replacement, inputBaseline: baseline)
        engine.update(deltaTime: .milliseconds(100))

        #expect(replacement.input.mouse.delta == .zero)
        #expect(replacement.input.mouse.buttons == [.right])
        #expect(engine.accumulatedTime == .zero)
        #expect(engine.completedTick == SimulationTick(rawValue: 1))
    }

    @Test func appendedSystemsRunInAlwaysThenSimulationOrder() {
        let recorder = ExecutionRecorder()
        let engine = Engine(alwaysSystems: [], systems: [])

        engine.addSystem(RecordingSystem(name: "simulation", recorder: recorder))
        engine.addAlwaysSystem(RecordingSystem(name: "always", recorder: recorder))
        engine.step()

        #expect(recorder.entries == ["always", "simulation"])
        #expect(engine.completedTick == SimulationTick(rawValue: 1))
    }

    @Test func replacingWorldStartsANewTickTimeline() {
        let engine = Engine(alwaysSystems: [], systems: [])
        engine.step()

        engine.replaceWorld(with: World())

        #expect(engine.completedTick == .zero)
        #expect(engine.accumulatedTime == .zero)
    }
}

private func inputSnapshot(
    session: UInt64 = 1,
    sequence: UInt64,
    pointerMotionTotal: SIMD2<Float> = .zero,
    pressedMouseButtons: Set<MouseButton> = []
) -> InputSnapshot {
    InputSnapshot(
        revision: InputRevision(session: session, sequence: sequence),
        pointerPosition: .zero,
        pointerMotionTotal: pointerMotionTotal,
        scrollTotal: .zero,
        pressedMouseButtons: pressedMouseButtons,
        pressedKeys: []
    )
}

private struct InputDeltaAccumulatorSystem: PSystem {
    mutating func update(world: inout World, deltaTime: Float) {
        world.camera.position.x += world.input.mouse.delta.x
    }
}

private struct StatefulSystem: PSystem {
    private var updateCount: Float = 0

    mutating func update(world: inout World, deltaTime: Float) {
        updateCount += 1
        world.camera.position.x = updateCount
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
