import Foundation
import Testing
@testable import Engine2

struct RealtimeAdvanceDriverIntegrationTests {
    @Test func driverCommitsExactRuntimePublicationAndPostStartInput() async throws {
        let inputRuntime = InputRuntime()
        let simulationRuntime = SimulationRuntime(
            worldBuilder: IntegrationMovingWorldBuilder(),
            configuration: .basicGame,
            inputBaseline: inputRuntime.latestInputSnapshot
        )
        let initialCamera = simulationRuntime.world.camera
        let baseInstant = SuspendingClock().now
        let clock = IntegrationTestClock(
            initialInstant: baseInstant,
            resumedInstants: [
                baseInstant.advanced(by: SimulationRuntime.fixedTimeStep)
            ]
        )
        let driver = RealtimeAdvanceDriver(
            advanceTarget: simulationRuntime,
            inputSource: inputRuntime,
            initialCursor: simulationRuntime.currentCursor,
            fixedTimeStep: SimulationRuntime.fixedTimeStep,
            pollInterval: SimulationRuntime.fixedTimeStep,
            catchUpPolicy: .interactive,
            isAdvancementEnabled: true,
            clock: clock
        )

        inputRuntime.start()
        driver.start()
        await clock.waitForPendingCount(1)

        // This event arrives after the driver's transition baseline but before
        // the first tick. The atomic rebase-then-ingest assignment must retain
        // it rather than swallowing it into a late baseline.
        inputRuntime.receive(
            .mouseDragged(
                delta: SIMD2<Float>(5, 0),
                position: SIMD2<Float>(20, 10)
            )
        )
        clock.resumeNext()

        let didAdvance = await eventually {
            simulationRuntime.currentCursor.tick == SimulationTick(rawValue: 1)
        }
        await driver.stopAndDrain()
        clock.resumeAll()
        inputRuntime.stop()

        let entity = try #require(
            simulationRuntime.world.positionComponents.entities.first
        )
        let position = try #require(
            simulationRuntime.world.positionComponents[entity]?.position
        )

        #expect(didAdvance)
        #expect(
            abs(
                position.x
                    - SimulationRuntime.fixedTimeStep.seconds
            ) < 0.0001
        )
        #expect(simulationRuntime.latestPresentationSnapshot.cursor == simulationRuntime.currentCursor)
        #expect(
            simulationRuntime.latestPresentationSnapshot.entityPresentations.first?.position ==
            position.singlePrecision
        )
        #expect(simulationRuntime.world.camera != initialCamera)
        #expect(
            simulationRuntime.latestPresentationSnapshot.camera ==
            simulationRuntime.world.camera
        )
        let renderFrame = RenderFrame(
            projecting: simulationRuntime.latestPresentationSnapshot
        )
        #expect(
            renderFrame.camera == simulationRuntime.world.camera
        )
        #expect(simulationRuntime.world.inputHistory.entries.first?.tokens == ["Mouse dx:+5 dy:+0"])
    }

    @Test
    func pausedCameraInputIsDiscardedAndFreshInputCommitsAfterResume() async {
        let inputRuntime = InputRuntime()
        let simulationRuntime = SimulationRuntime(
            worldBuilder: BasicWorldBuilder(),
            configuration: .basicGame,
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
        let clock = IntegrationTestClock(
            initialInstant: baseInstant,
            resumedInstants: [
                firstInstant,
                secondInstant,
                thirdInstant
            ]
        )
        let driver = RealtimeAdvanceDriver(
            advanceTarget: simulationRuntime,
            inputSource: inputRuntime,
            initialCursor: simulationRuntime.currentCursor,
            fixedTimeStep: SimulationRuntime.fixedTimeStep,
            pollInterval: SimulationRuntime.fixedTimeStep,
            catchUpPolicy: .interactive,
            isAdvancementEnabled: true,
            clock: clock
        )

        inputRuntime.start()
        driver.start()
        await clock.waitForPendingCount(1)

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
        clock.resumeNext()
        await clock.waitForPendingCount(1)
        clock.resumeNext()

        let baselineTickCompleted = await eventually {
            simulationRuntime.currentCursor.tick == SimulationTick(rawValue: 1)
        }
        guard baselineTickCompleted else {
            await driver.stopAndDrain()
            clock.resumeAll()
            inputRuntime.stop()
            Issue.record("The resume-baseline tick never completed.")
            return
        }
        #expect(simulationRuntime.world.camera == initialCamera)
        #expect(
            simulationRuntime.latestPresentationSnapshot.camera ==
            initialCamera
        )

        await clock.waitForPendingCount(1)
        inputRuntime.receive(
            .mouseDragged(
                delta: SIMD2<Float>(10, 0),
                position: SIMD2<Float>(20, 20)
            )
        )
        #expect(simulationRuntime.world.camera == initialCamera)

        clock.resumeNext()
        let activeTickCompleted = await eventually {
            simulationRuntime.currentCursor.tick == SimulationTick(rawValue: 2)
        }

        await driver.stopAndDrain()
        clock.resumeAll()
        inputRuntime.stop()

        #expect(activeTickCompleted)
        let expectedCameraPosition = SIMD3<Float>(
            sinf(0.1) * 8,
            0,
            cosf(0.1) * 8
        )
        #expect(
            simulationRuntime.world.camera.position.isApproximately(
                expectedCameraPosition
            )
        )
        #expect(
            simulationRuntime.latestPresentationSnapshot.camera ==
            simulationRuntime.world.camera
        )
        #expect(
            simulationRuntime.world.inputHistory.entries.first?.tokens ==
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
                materialID: .warmDielectric,
                position: .zero,
                velocity: SIMD3<Double>(1, 0, 0)
            )
            return world
        }
    }

    private final class IntegrationTestClock: PRealtimeClock {
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
                Issue.record("No integration sleep was pending.")
                return
            }
            guard resumedInstants.isEmpty == false else {
                Issue.record("No integration wake instant was scripted.")
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
                let continuations = countWaiters.removeValue(forKey: count) ?? []
                continuations.forEach { $0.resume() }
            }
        }
    }
}
