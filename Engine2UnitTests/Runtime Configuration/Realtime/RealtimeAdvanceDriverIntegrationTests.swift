import Testing
@testable import Engine2

struct RealtimeAdvanceDriverIntegrationTests {
    @Test @MainActor func driverCommitsExactRuntimePublicationAndPostStartInput() async throws {
        let inputRuntime = InputRuntime()
        let simulationRuntime = SimulationRuntime(
            worldBuilder: IntegrationMovingWorldBuilder(),
            inputBaseline: inputRuntime.latestInputSnapshot
        )
        let baseInstant = SuspendingClock().now
        let elapsedSource = IntegrationInstantSource(
            samples: [
                baseInstant,
                baseInstant.advanced(by: SimulationRuntime.fixedTimeStep)
            ]
        )
        let sleeper = IntegrationControlledSleeper()
        let driver = RealtimeAdvanceDriver(
            advanceTarget: simulationRuntime,
            inputSource: inputRuntime,
            initialCursor: simulationRuntime.currentCursor,
            fixedTimeStep: SimulationRuntime.fixedTimeStep,
            pollInterval: SimulationRuntime.fixedTimeStep,
            clockFactory: { SystemClock(timeSource: elapsedSource.next) },
            scheduleTimeSource: { baseInstant },
            sleeper: sleeper.sleep(until:)
        )

        inputRuntime.start()
        driver.start()
        await sleeper.waitForPendingCount(1)

        // This event arrives after the driver's transition baseline but before
        // the first tick. The atomic rebase-then-ingest assignment must retain
        // it rather than swallowing it into a late baseline.
        inputRuntime.receive(
            .mouseDragged(
                delta: SIMD2<Float>(5, 0),
                position: SIMD2<Float>(20, 10)
            )
        )
        await sleeper.resumeNext()

        let didAdvance = await eventually {
            simulationRuntime.currentCursor.tick == SimulationTick(rawValue: 1)
        }
        await driver.stopAndDrain()
        await sleeper.resumeAll()
        inputRuntime.stop()

        let entity = try #require(
            simulationRuntime.world.positionComponents.entities.first
        )
        let position = try #require(
            simulationRuntime.world.positionComponents[entity]?.position
        )

        #expect(didAdvance)
        #expect(
            abs(position.x - SimulationRuntime.fixedTimeStep.seconds) <
            0.0001
        )
        #expect(simulationRuntime.latestPresentationSnapshot.cursor == simulationRuntime.currentCursor)
        #expect(
            simulationRuntime.latestPresentationSnapshot.entityPresentations.first?.position ==
            position
        )
        #expect(simulationRuntime.world.input.history.first?.tokens == ["Mouse dx:+5 dy:+0"])
    }

    @MainActor
    private func eventually(_ condition: () -> Bool) async -> Bool {
        for _ in 0..<10_000 {
            if condition() {
                return true
            }
            await Task.yield()
        }

        return false
    }
}

private struct IntegrationMovingWorldBuilder: PWorldBuilder {
    func buildWorld() -> World {
        let world = World()
        _ = Ball(
            in: world,
            position: .zero,
            velocity: SIMD3<Float>(1, 0, 0)
        )
        return world
    }
}

private final class IntegrationInstantSource {
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

private actor IntegrationControlledSleeper {
    private struct Waiter {
        let continuation: CheckedContinuation<Void, any Error>
    }

    private var waiters: [Waiter] = []
    private var countWaiters: [
        Int: [CheckedContinuation<Void, Never>]
    ] = [:]

    func sleep(until deadline: SuspendingClock.Instant) async throws {
        try await withCheckedThrowingContinuation { continuation in
            waiters.append(Waiter(continuation: continuation))
            resumeSatisfiedCountWaiters()
        }
    }

    func waitForPendingCount(_ count: Int) async {
        guard waiters.count < count else {
            return
        }

        await withCheckedContinuation { continuation in
            countWaiters[count, default: []].append(continuation)
        }
    }

    func resumeNext() {
        guard waiters.isEmpty == false else {
            Issue.record("No integration sleep was pending.")
            return
        }

        waiters.removeFirst().continuation.resume()
    }

    func resumeAll() {
        let pendingWaiters = waiters
        waiters.removeAll()
        for waiter in pendingWaiters {
            waiter.continuation.resume()
        }
    }

    private func resumeSatisfiedCountWaiters() {
        let satisfiedCounts = countWaiters.keys.filter {
            $0 <= waiters.count
        }
        for count in satisfiedCounts {
            let continuations = countWaiters.removeValue(forKey: count) ?? []
            continuations.forEach { $0.resume() }
        }
    }
}
