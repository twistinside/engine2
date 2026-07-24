import Foundation
import ImageIO
import Testing
@testable import Engine2

/// Scenario-level proof that Runtime topology changes do not change Simulation
/// semantics and that optional peers remain genuinely optional.
struct RuntimeCompositionScenarioTests {
    @Test @MainActor
    func clockDrivenSimulationRunsOneSecondWithoutInputOrRenderPeers() async throws {
        let runtime = await Self.runClockDrivenSimulation(
            stepCount: SimulationStepCount(rawValue: 60)
        )

        let entityID = try #require(
            runtime.world.positionComponents.entities.first
        )
        let position = try #require(
            runtime.world.positionComponents[entityID]?.position
        )

        #expect(abs(position.x - 1) < 0.0001)
        #expect(runtime.world.input.history.isEmpty)
        #expect(
            runtime.latestPresentationSnapshot.entityPresentations.first?.position
                == position
        )
    }

    @Test @MainActor
    func clockManualAndOfflineTopologiesReachEquivalentTickTwentyState() async throws {
        let gameContent = BasicGameContent(
            worldBuilder: MovingWorldBuilder()
        )
        let clockDriven = await Self.runClockDrivenSimulation(
            stepCount: SimulationStepCount(rawValue: 20)
        )
        let manual = ManualConfiguration().makeAssembly(
            gameContent: gameContent
        )
        let manualOutcome = await manual.advanceTarget.advance(
            SimulationAdvanceRequest(
                expectedCursor: manual.simulationRuntime.currentCursor,
                stepCount: SimulationStepCount(rawValue: 20)
            )
        )
        guard case let .completed(manualResult) = manualOutcome else {
            Issue.record("Manual composition did not complete twenty exact ticks.")
            return
        }

        let offline = try OfflineCaptureConfiguration().makeAssembly(
            gameContent: gameContent
        )
        let size = try RenderPixelSize(width: 64, height: 64)
        let viewpoint = RenderViewpoint(
            id: RenderViewpointID(),
            revision: .zero,
            camera: Camera()
        )
        let settings = OffscreenRenderSettings(size: size)

        let firstOutcome = await offline.captureTarget.capture(
            OfflineCaptureRequest(
                advanceRequest: SimulationAdvanceRequest(
                    expectedCursor: offline.initialCursor,
                    stepCount: SimulationStepCount(rawValue: 10)
                ),
                viewpoint: viewpoint,
                renderSettings: settings,
                jpegSettings: JPEGEncodingSettings(quality: .maximum)
            )
        )
        guard case let .completed(firstResult) = firstOutcome else {
            Issue.record("The first ten-tick offline capture did not complete.")
            return
        }

        let secondOutcome = await offline.captureTarget.capture(
            OfflineCaptureRequest(
                advanceRequest: SimulationAdvanceRequest(
                    expectedCursor: firstResult.advanceResult.finalCursor,
                    stepCount: SimulationStepCount(rawValue: 10)
                ),
                viewpoint: viewpoint,
                renderSettings: settings,
                jpegSettings: JPEGEncodingSettings(quality: .maximum)
            )
        )
        guard case let .completed(secondResult) = secondOutcome else {
            Issue.record("The second ten-tick offline capture did not complete.")
            return
        }

        let currentOutcome = await offline.captureTarget.captureCurrent(
            OfflineCurrentCaptureRequest(
                expectedCursor: secondResult.advanceResult.finalCursor,
                viewpoint: viewpoint,
                renderSettings: settings,
                jpegSettings: JPEGEncodingSettings(quality: .maximum)
            )
        )
        guard case let .completed(currentResult) = currentOutcome else {
            Issue.record("The non-advancing current capture did not complete.")
            return
        }

        #expect(firstResult.advanceResult.finalCursor.tick == SimulationTick(rawValue: 10))
        #expect(secondResult.advanceResult.finalCursor.tick == SimulationTick(rawValue: 20))
        #expect(
            currentResult.sourceSnapshot
                == secondResult.advanceResult.finalPresentationSnapshot
        )
        #expect(
            manualResult.finalPresentationSnapshot.entityPresentations
                == secondResult.advanceResult.finalPresentationSnapshot.entityPresentations
        )
        #expect(
            manualResult.finalPresentationSnapshot.camera
                == secondResult.advanceResult.finalPresentationSnapshot.camera
        )
        #expect(
            clockDriven.latestPresentationSnapshot.entityPresentations
                == manualResult.finalPresentationSnapshot.entityPresentations
        )
        #expect(
            clockDriven.latestPresentationSnapshot.camera
                == manualResult.finalPresentationSnapshot.camera
        )

        try Self.expectDecodableJPEG(firstResult.artifact, size: size)
        try Self.expectDecodableJPEG(secondResult.artifact, size: size)
        try Self.expectDecodableJPEG(currentResult.artifact, size: size)
    }

    @MainActor
    private static func runClockDrivenSimulation(
        stepCount: SimulationStepCount
    ) async -> SimulationRuntime {
        let runtime = SimulationRuntime(
            worldBuilder: MovingWorldBuilder()
        )
        let baseInstant = SuspendingClock().now
        let elapsed = (0..<stepCount.rawValue).reduce(Duration.zero) {
            accumulated,
            _ in
            accumulated + SimulationRuntime.fixedTimeStep
        }
        let elapsedSource = InstantSource(
            samples: [
                baseInstant,
                baseInstant.advanced(by: elapsed)
            ]
        )
        let sleeper = ControlledSleeper()
        let driver = RealtimeAdvanceDriver(
            advanceTarget: runtime,
            initialCursor: runtime.currentCursor,
            fixedTimeStep: SimulationRuntime.fixedTimeStep,
            pollInterval: SimulationRuntime.fixedTimeStep,
            catchUpPolicy: RealtimeCatchUpPolicy(
                maximumStepsPerWake: stepCount,
                backlogTreatment: .preserve
            ),
            clockFactory: {
                SystemClock(timeSource: elapsedSource.next)
            },
            scheduleTimeSource: { baseInstant },
            sleeper: sleeper.sleep(until:)
        )

        driver.start()
        await sleeper.waitForPendingCount(1)
        await sleeper.resumeNext()

        let expectedTick = SimulationTick(
            rawValue: UInt64(stepCount.rawValue)
        )
        let didAdvance = await Self.eventually {
            runtime.currentCursor.tick == expectedTick
        }
        await driver.stopAndDrain()
        await sleeper.resumeAll()

        #expect(didAdvance)
        return runtime
    }

    private static func eventually(
        _ condition: @MainActor () -> Bool
    ) async -> Bool {
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

    private static func expectDecodableJPEG(
        _ artifact: RenderedImageArtifact,
        size: RenderPixelSize
    ) throws {
        #expect(artifact.format == .jpeg)
        #expect(artifact.encodedData.isEmpty == false)

        let source = try #require(
            CGImageSourceCreateWithData(
                artifact.encodedData as CFData,
                nil
            )
        )
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        #expect(image.width == size.width)
        #expect(image.height == size.height)
    }

    private struct MovingWorldBuilder: PWorldBuilder {
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

    private final class InstantSource {
        private let samples: [SuspendingClock.Instant]
        private var nextIndex = 0

        init(samples: [SuspendingClock.Instant]) {
            precondition(samples.isEmpty == false)
            self.samples = samples
        }

        func next() -> SuspendingClock.Instant {
            let sample = samples[min(nextIndex, samples.count - 1)]
            nextIndex += 1
            return sample
        }
    }

    private actor ControlledSleeper {
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
                Issue.record("No composition sleep was pending.")
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
                let continuations =
                    countWaiters.removeValue(forKey: count) ?? []
                continuations.forEach { $0.resume() }
            }
        }
    }
}
