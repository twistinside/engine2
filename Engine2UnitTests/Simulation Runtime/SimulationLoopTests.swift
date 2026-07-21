import Foundation
import Testing
@testable import Engine2

private final class SampledInstantSource {
    private let samples: [SuspendingClock.Instant]
    private var nextIndex = 0

    init(samples: [SuspendingClock.Instant]) {
        self.samples = samples
    }

    func next() -> SuspendingClock.Instant {
        let sample = samples[min(nextIndex, samples.count - 1)]
        nextIndex += 1
        return sample
    }
}

private actor TestSleeper {
    private let results: [Result<Void, any Error>]
    private var nextIndex = 0
    private var requestedDeadlines: [SuspendingClock.Instant] = []

    init(results: [Result<Void, any Error>]) {
        self.results = results
    }

    func sleep(until deadline: SuspendingClock.Instant) async throws {
        requestedDeadlines.append(deadline)
        let index = min(nextIndex, results.count - 1)
        nextIndex += 1
        try results[index].get()
    }

    func recordedDeadlines() -> [SuspendingClock.Instant] {
        requestedDeadlines
    }
}

struct SimulationLoopTests {
    @Test @MainActor func deterministicPollsReportZeroOneAndCatchUpSteps() throws {
        let fixedTimeStep = Duration.milliseconds(100)
        let wallDeltas = [
            Duration.milliseconds(50),
            Duration.milliseconds(100),
            Duration.milliseconds(250)
        ]
        let expectedSteps = [0, 1, 2]
        let expectedBacklogs = [50_000_000, 0, 50_000_000]

        for index in wallDeltas.indices {
            let sink = RecordingDiagnosticsSink()
            let diagnostics = DiagnosticsEmitter(sink: sink)
            let engine = Engine(
                world: World(),
                fixedTimeStep: fixedTimeStep,
                diagnostics: diagnostics,
                alwaysSystems: [],
                systems: []
            )
            let loop = SimulationLoop(
                engine: engine,
                diagnostics: diagnostics,
                pollInterval: fixedTimeStep
            )
            let baseInstant = SuspendingClock().now
            let source = SampledInstantSource(
                samples: [baseInstant, baseInstant.advanced(by: wallDeltas[index])]
            )
            var clock = SystemClock(timeSource: source.next)

            loop.pollOnce(using: &clock)

            let pollSamples = sink.samples.compactMap { sample -> SimulationPollDiagnostics? in
                guard case let .simulationPoll(payload) = sample.payload else {
                    return nil
                }
                return payload
            }
            #expect(pollSamples.count == 1)
            let poll = try #require(pollSamples.first)
            #expect(poll.sampledWallDeltaNanoseconds == wallDeltas[index].diagnosticsNanoseconds)
            #expect(poll.stepsCompleted == expectedSteps[index])
            #expect(poll.backlogBeforeNanoseconds == 0)
            #expect(poll.backlogAfterNanoseconds == expectedBacklogs[index])
        }
    }

    @Test @MainActor func startAndStopAreIdempotentAndReportLifecycleOnce() {
        let engine = Engine(world: World(), systems: [])
        var clockCreationCount = 0
        var runningStates: [Bool] = []
        let simulationLoop = SimulationLoop(
            engine: engine,
            pollInterval: .seconds(60),
            clockFactory: {
                clockCreationCount += 1
                return SystemClock()
            },
            sleeper: { _ in
                try await Task.sleep(for: .seconds(60))
            }
        )
        simulationLoop.runningStateDidChange = { isRunning in
            runningStates.append(isRunning)
        }

        simulationLoop.start()
        simulationLoop.start()

        #expect(simulationLoop.isRunning)
        #expect(clockCreationCount == 1)
        #expect(runningStates == [true])

        simulationLoop.stop()
        simulationLoop.stop()

        #expect(simulationLoop.isRunning == false)
        #expect(runningStates == [true, false])
    }

    @Test @MainActor func appTaskFeedsElapsedTimeIntoEngine() async throws {
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
        let baseInstant = SuspendingClock().now
        let instantSource = SampledInstantSource(
            samples: [
                baseInstant,
                baseInstant.advanced(by: .milliseconds(500))
            ]
        )
        let sleeper = TestSleeper(
            results: [
                .success(()),
                .failure(CancellationError())
            ]
        )
        let key = KeyboardKey.make(
            keyCode: 13,
            charactersIgnoringModifiers: "w"
        )
        let inputSource = TestInputSnapshotSource(
            snapshot: InputSnapshot(
                revision: InputRevision(session: 1, sequence: 1),
                pointerPosition: .zero,
                pointerMotionTotal: .zero,
                scrollTotal: .zero,
                pressedMouseButtons: [],
                pressedKeys: [key]
            )
        )
        let simulationLoop = SimulationLoop(
            engine: engine,
            inputSource: inputSource,
            pollInterval: .milliseconds(500),
            clockFactory: {
                SystemClock(timeSource: instantSource.next)
            },
            sleeper: sleeper.sleep(until:)
        )
        var completedTicks: [SimulationTick] = []
        simulationLoop.fixedStepsDidComplete = { tick in
            completedTicks.append(tick)
        }

        simulationLoop.start()

        for _ in 0..<100 {
            if !simulationLoop.isRunning {
                break
            }

            await Task.yield()
        }

        #expect(simulationLoop.isRunning == false)
        #expect(world.motionComponents[entity]?.velocity == SIMD3<Float>(6, 4, 5.5))
        #expect(world.positionComponents[entity]?.position == SIMD3<Float>(4, 4, 5.75))
        #expect(engine.accumulatedTime == .zero)
        #expect(completedTicks == [SimulationTick(rawValue: 1)])
        #expect(world.input.keyboard.keys == [key])
        #expect(world.input.history.first?.tokens == ["W"])
    }

    @Test @MainActor func appTaskRebasesSleepAgainstAbsoluteDeadlinesAfterOversleep() async throws {
        let engine = Engine(world: World(), fixedTimeStep: .milliseconds(100), systems: [])
        let baseInstant = SuspendingClock().now
        let engineTimeSource = SampledInstantSource(
            samples: [
                baseInstant,
                baseInstant.advanced(by: .milliseconds(110))
            ]
        )
        let scheduleTimeSource = SampledInstantSource(
            samples: [
                baseInstant,
                baseInstant.advanced(by: .milliseconds(110))
            ]
        )
        let sleeper = TestSleeper(
            results: [
                .success(()),
                .failure(CancellationError())
            ]
        )
        let simulationLoop = SimulationLoop(
            engine: engine,
            pollInterval: .milliseconds(100),
            clockFactory: {
                SystemClock(timeSource: engineTimeSource.next)
            },
            scheduleTimeSource: scheduleTimeSource.next,
            sleeper: sleeper.sleep(until:)
        )

        simulationLoop.start()

        for _ in 0..<100 {
            if !simulationLoop.isRunning {
                break
            }

            await Task.yield()
        }

        let requestedDeadlines = await sleeper.recordedDeadlines()

        #expect(simulationLoop.isRunning == false)
        #expect(
            requestedDeadlines == [
                baseInstant.advanced(by: .milliseconds(100)),
                baseInstant.advanced(by: .milliseconds(200))
            ]
        )
        #expect(engine.accumulatedTime == .milliseconds(10))
    }
}

@MainActor
private final class TestInputSnapshotSource: PInputSnapshotSource {
    var latestInputSnapshot: InputSnapshot

    init(snapshot: InputSnapshot) {
        latestInputSnapshot = snapshot
    }
}
