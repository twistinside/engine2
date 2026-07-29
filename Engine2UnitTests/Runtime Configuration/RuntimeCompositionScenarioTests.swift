import Foundation
import ImageIO
import Testing
@testable import Engine2
@testable import BasicGameContent
@testable import Engine2ManualAssembly
@testable import Engine2OfflineCaptureAssembly
@testable import Engine2RealtimeAssembly

/// Scenario-level proof that Runtime topology changes do not change Simulation
/// semantics and that optional peers remain genuinely optional.
struct RuntimeCompositionScenarioTests {
    @Test
    func clockDrivenSimulationRunsOneSecondWithoutInputOrRenderPeers() async throws {
        let stepCount = SimulationStepCount(rawValue: 60)
        let runtime = await runClockDrivenSimulation(
            stepCount: stepCount
        )

        let entityID = try #require(
            runtime.world.positionComponents.entities.first
        )
        let position = try #require(
            runtime.world.positionComponents[entityID]?.position
        )

        #expect(abs(position.x - 1) < 0.0001)
        #expect(runtime.world.inputHistory.entries.isEmpty)
        #expect(
            runtime.latestPresentationSnapshot.entityPresentations.first?.position
                == position
        )
    }

    @Test
    func clockManualAndOfflineTopologiesReachEquivalentTickTwentyState() async throws {
        let worldBuilder = MovingWorldBuilder()
        let gameContent = BasicGameContent(
            worldBuilder: worldBuilder
        )
        let twentySteps = SimulationStepCount(rawValue: 20)
        let clockDriven = await runClockDrivenSimulation(
            stepCount: twentySteps
        )
        let manual = ManualAssembly(
            gameContent: gameContent
        )
        let manualRequest = SimulationAdvanceRequest(
            expectedCursor: manual.simulationRuntime.currentCursor,
            stepCount: twentySteps,
            inputAssignment: .none
        )
        let manualOutcome = await manual.advanceTarget.advance(
            manualRequest
        )
        guard case let .completed(manualResult) = manualOutcome else {
            Issue.record("Manual composition did not complete twenty exact ticks.")
            return
        }

        let offline = try OfflineCaptureAssembly(
            gameContent: gameContent,
            renderLimits: .conservative,
            sessionID: SimulationSessionID()
        )
        let size = try RenderPixelSize(width: 64, height: 64)
        let viewpointID = RenderViewpointID()
        let viewpoint = RenderViewpoint(
            id: viewpointID,
            revision: .zero,
            camera: .standard
        )
        let settings = OffscreenRenderSettings(
            size: size,
            outputMode: .surface,
            exposure: .validation
        )

        let tenSteps = SimulationStepCount(rawValue: 10)
        let firstAdvanceRequest = SimulationAdvanceRequest(
            expectedCursor: offline.initialCursor,
            stepCount: tenSteps,
            inputAssignment: .none
        )
        let firstRenderRequestID = OffscreenRenderRequestID()
        let firstRequest = OfflineCaptureRequest(
            advanceRequest: firstAdvanceRequest,
            renderRequestID: firstRenderRequestID,
            viewpoint: viewpoint,
            renderSettings: settings,
            encoding: ImageArtifactEncoding.jpeg(quality: .maximum)
        )
        let firstOutcome = await offline.captureTarget.capture(
            firstRequest
        )
        guard case let .completed(firstResult) = firstOutcome else {
            Issue.record("The first ten-tick offline capture did not complete.")
            return
        }

        let secondAdvanceRequest = SimulationAdvanceRequest(
            expectedCursor: firstResult.advanceResult.finalCursor,
            stepCount: tenSteps,
            inputAssignment: .none
        )
        let secondRenderRequestID = OffscreenRenderRequestID()
        let secondRequest = OfflineCaptureRequest(
            advanceRequest: secondAdvanceRequest,
            renderRequestID: secondRenderRequestID,
            viewpoint: viewpoint,
            renderSettings: settings,
            encoding: ImageArtifactEncoding.jpeg(quality: .maximum)
        )
        let secondOutcome = await offline.captureTarget.capture(
            secondRequest
        )
        guard case let .completed(secondResult) = secondOutcome else {
            Issue.record("The second ten-tick offline capture did not complete.")
            return
        }

        let currentRenderRequestID = OffscreenRenderRequestID()
        let currentRequest = OfflineCurrentCaptureRequest(
            expectedCursor: secondResult.advanceResult.finalCursor,
            renderRequestID: currentRenderRequestID,
            viewpoint: viewpoint,
            renderSettings: settings,
            encoding: ImageArtifactEncoding.jpeg(quality: .maximum)
        )
        let currentOutcome = await offline.captureTarget.captureCurrent(
            currentRequest
        )
        guard case let .completed(currentResult) = currentOutcome else {
            Issue.record("The non-advancing current capture did not complete.")
            return
        }

        let expectedFirstTick = SimulationTick(rawValue: 10)
        let expectedSecondTick = SimulationTick(rawValue: 20)
        #expect(firstResult.advanceResult.finalCursor.tick == expectedFirstTick)
        #expect(secondResult.advanceResult.finalCursor.tick == expectedSecondTick)
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

        try expectDecodableJPEG(firstResult.artifact, size: size)
        try expectDecodableJPEG(secondResult.artifact, size: size)
        try expectDecodableJPEG(currentResult.artifact, size: size)
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

    private func expectDecodableJPEG(_ artifact: RenderedImageArtifact, size: RenderPixelSize) throws {
        guard case .jpeg = artifact.encoding else {
            Issue.record("Expected the scenario artifact to use JPEG.")
            return
        }
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
                materialID: .warmDielectric,
                position: .zero,
                velocity: SIMD3<Float>(1, 0, 0)
            )
            return world
        }
    }

    private final class CompositionTestClock: PRealtimeClock {
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
