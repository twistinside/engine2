import Foundation
import Testing
@testable import Engine2

/// Scenario-level proof that real-time composition preserves Simulation semantics.
struct RuntimeCompositionScenarioTests {
    @Test
    func clockDrivenSimulationRunsOneSecondWithoutInputOrRenderPeers() async throws {
        let stepCount = SimulationStepCount(rawValue: 60)
        let runtime = await runClockDrivenSimulation(
            stepCount: stepCount
        )

        let entityID = try #require(
            runtime.world.components[PositionComponent.self].entities.first
        )
        let position = try #require(
            runtime.world.components[PositionComponent.self][entityID]?.position
        )

        #expect(abs(position.x - 1) < 0.0001)
        #expect(
            runtime.latestPresentationSnapshot.entityPresentations.first?.position
                == position.singlePrecision
        )
    }

    private func runClockDrivenSimulation(stepCount: SimulationStepCount) async -> SimulationRuntime {
        let worldBuilder = MovingWorldBuilder()
        let runtime = SimulationRuntime(
            worldBuilder: worldBuilder,
            configuration: .basicGame,
            inputBaseline: nil
        )
        let baseInstant = SuspendingClock().now
        let elapsed = (0..<stepCount.rawValue).reduce(Duration.zero) {
            accumulated,
            _ in
            accumulated + SimulationRuntime.fixedTimeStep
        }
        let clock = CompositionTestClock(
            initialInstant: baseInstant,
            resumedInstants: [baseInstant.advanced(by: elapsed)]
        )
        let catchUpPolicy = RealtimeCatchUpPolicy(
            maximumStepsPerWake: stepCount,
            backlogTreatment: .preserve
        )
        let driver = RealtimeAdvanceDriver(
            advanceTarget: runtime,
            inputSource: nil,
            initialCursor: runtime.currentCursor,
            fixedTimeStep: SimulationRuntime.fixedTimeStep,
            pollInterval: SimulationRuntime.fixedTimeStep,
            catchUpPolicy: catchUpPolicy,
            isAdvancementEnabled: true,
            clock: clock
        )

        driver.start()
        await clock.waitForPendingCount(1)
        clock.resumeNext()

        let expectedRawTick = UInt64(stepCount.rawValue)
        let expectedTick = SimulationTick(
            rawValue: expectedRawTick
        )
        let didAdvance = await eventually {
            runtime.currentCursor.tick == expectedTick
        }
        await driver.stopAndDrain()
        clock.resumeAll()

        #expect(didAdvance)
        return runtime
    }

    private func eventually(_ condition: @MainActor () -> Bool) async -> Bool {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(5))

        while clock.now < deadline {
            if condition() {
                return true
            }
            await Task.yield()
        }

        return false
    }

    private struct MovingWorldBuilder: WorldBuilder {
        func buildWorld() -> World {
            let world = World()
            _ = Ball(
                in: world,
                materialID: .warmDielectric,
                position: .zero,
                velocity: SIMD3<Double>(1, 0, 0)
            )
            return world
        }
    }

    private final class CompositionTestClock: RealtimeClock {
        private struct Waiter {
            let continuation: CheckedContinuation<Void, any Error>
        }

        private var currentInstant: SuspendingClock.Instant
        private var resumedInstants: [SuspendingClock.Instant]
        private var waiters: [Waiter] = []
        private var countWaiters: [
            Int: [CheckedContinuation<Void, Never>]
        ] = [:]

        var now: SuspendingClock.Instant {
            currentInstant
        }

        init(
            initialInstant: SuspendingClock.Instant,
            resumedInstants: [SuspendingClock.Instant]
        ) {
            self.currentInstant = initialInstant
            self.resumedInstants = resumedInstants
        }

        func sleep(until _: SuspendingClock.Instant) async throws {
            try await withCheckedThrowingContinuation { continuation in
                let waiter = Waiter(continuation: continuation)
                waiters.append(waiter)
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
                Issue.record("No composition sleep was pending.")
                return
            }
            guard resumedInstants.isEmpty == false else {
                Issue.record("No composition wake instant was scripted.")
                return
            }

            currentInstant = resumedInstants.removeFirst()
            let waiter = waiters.removeFirst()
            waiter.continuation.resume()
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
                let continuations =
                    countWaiters.removeValue(forKey: count) ?? []
                continuations.forEach { $0.resume() }
            }
        }
    }
}
