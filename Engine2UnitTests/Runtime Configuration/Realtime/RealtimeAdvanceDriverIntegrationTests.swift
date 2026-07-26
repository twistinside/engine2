import Foundation
import Testing
@testable import Engine2

struct RealtimeAdvanceDriverIntegrationTests {
    @Test func driverCommitsExactRuntimePublicationAndPostStartInput() async throws {
        let inputRuntime = InputRuntime()
        let simulationRuntime = SimulationRuntime(
            worldBuilder: IntegrationMovingWorldBuilder(),
            inputBaseline: inputRuntime.latestInputSnapshot
        )
        let initialCamera = simulationRuntime.world.camera
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
        #expect(simulationRuntime.world.camera != initialCamera)
        #expect(
            simulationRuntime.latestPresentationSnapshot.camera ==
            simulationRuntime.world.camera
        )
        #expect(
            RenderFrame(
                projecting: simulationRuntime.latestPresentationSnapshot
            ).camera == simulationRuntime.world.camera
        )
        #expect(simulationRuntime.world.input.history.first?.tokens == ["Mouse dx:+5 dy:+0"])
    }

    @Test
    func pausedCameraInputIsDiscardedAndFreshInputCommitsAfterResume() async {
        let inputRuntime = InputRuntime()
        let simulationRuntime = SimulationRuntime(
            worldBuilder: BasicWorldBuilder(),
            inputBaseline: inputRuntime.latestInputSnapshot
        )
        let initialCamera = simulationRuntime.world.camera
        let baseInstant = SuspendingClock().now
        let firstInstant = baseInstant.advanced(
            by: SimulationRuntime.fixedTimeStep
        )
        let secondInstant = firstInstant.advanced(
            by: SimulationRuntime.fixedTimeStep
        )
        let thirdInstant = secondInstant.advanced(
            by: SimulationRuntime.fixedTimeStep
        )
        let elapsedSource = IntegrationInstantSource(
            samples: [
                baseInstant,
                firstInstant,
                secondInstant,
                thirdInstant
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

        driver.pauseAdvancement()
        inputRuntime.receive(
            .mouseDragged(
                delta: SIMD2<Float>(50, 0),
                position: SIMD2<Float>(10, 20)
            )
        )
        inputRuntime.receive(.scroll(delta: SIMD2<Float>(0, 25)))

        #expect(simulationRuntime.currentCursor.tick == .zero)
        #expect(simulationRuntime.world.camera == initialCamera)
        #expect(
            simulationRuntime.latestPresentationSnapshot.camera ==
            initialCamera
        )

        driver.resumeAdvancement()
        await sleeper.resumeNext()
        await sleeper.waitForPendingCount(1)
        await sleeper.resumeNext()

        let baselineTickCompleted = await eventually {
            simulationRuntime.currentCursor.tick == SimulationTick(rawValue: 1)
        }
        guard baselineTickCompleted else {
            await driver.stopAndDrain()
            await sleeper.resumeAll()
            inputRuntime.stop()
            Issue.record("The resume-baseline tick never completed.")
            return
        }
        #expect(simulationRuntime.world.camera == initialCamera)
        #expect(
            simulationRuntime.latestPresentationSnapshot.camera ==
            initialCamera
        )

        await sleeper.waitForPendingCount(1)
        inputRuntime.receive(
            .mouseDragged(
                delta: SIMD2<Float>(10, 0),
                position: SIMD2<Float>(20, 20)
            )
        )
        #expect(simulationRuntime.world.camera == initialCamera)

        await sleeper.resumeNext()
        let activeTickCompleted = await eventually {
            simulationRuntime.currentCursor.tick == SimulationTick(rawValue: 2)
        }

        await driver.stopAndDrain()
        await sleeper.resumeAll()
        inputRuntime.stop()

        #expect(activeTickCompleted)
        #expect(
            simulationRuntime.world.camera.position.isApproximately(
                SIMD3<Float>(
                    sinf(0.1) * 8,
                    0,
                    cosf(0.1) * 8
                )
            )
        )
        #expect(
            simulationRuntime.latestPresentationSnapshot.camera ==
            simulationRuntime.world.camera
        )
        #expect(
            simulationRuntime.world.input.history.first?.tokens ==
            ["Mouse dx:+10 dy:+0"]
        )
    }

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

private extension SIMD3 where Scalar == Float {
    func isApproximately(_ other: SIMD3<Float>, tolerance: Float = 0.0001) -> Bool {
        abs(x - other.x) <= tolerance
            && abs(y - other.y) <= tolerance
            && abs(z - other.z) <= tolerance
    }
}

private extension RealtimeAdvanceDriverIntegrationTests {
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
}
