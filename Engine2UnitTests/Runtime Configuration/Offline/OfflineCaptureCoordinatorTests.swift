import Foundation
import simd
import Testing
@testable import Engine2

struct OfflineCaptureCoordinatorTests {
    @Test func completesInOrderUsingTheExactAdvancedSnapshot() async throws {
        let fixture = try Self.makeFixture()
        let probe = Probe(
            encodingResults: [.success(fixture.artifact)]
        )
        let advanceTarget = ScriptedAdvanceTarget(
            scripts: [.immediate(.completed(fixture.advanceResult))],
            probe: probe
        )
        let renderTarget = ScriptedRenderTarget(
            scripts: [.immediate(.completed(fixture.renderResult))],
            probe: probe
        )
        let coordinator = Self.coordinator(
            advanceTarget: advanceTarget,
            renderTarget: renderTarget,
            probe: probe
        )

        let outcome = await coordinator.capture(fixture.request)

        #expect(
            outcome == .completed(
                OfflineCaptureResult(
                    advanceResult: fixture.advanceResult,
                    artifact: fixture.artifact
                )
            )
        )
        #expect(probe.recordedStages() == [.advance, .render, .encode])

        let advanceRequests = await advanceTarget.recordedRequests()
        let advanceRequest = try #require(advanceRequests.first)
        #expect(advanceRequests.count == 1)
        #expect(
            advanceRequest.expectedCursor ==
            fixture.request.advanceRequest.expectedCursor
        )
        #expect(
            advanceRequest.stepCount ==
            fixture.request.advanceRequest.stepCount
        )
        guard case .none = advanceRequest.inputAssignment else {
            Issue.record("Coordinator changed the exact input assignment.")
            return
        }

        let renderRequests = await renderTarget.recordedRequests()
        #expect(renderRequests == [fixture.renderRequest])
        #expect(
            renderRequests.first?.presentationSnapshot ==
            fixture.advanceResult.finalPresentationSnapshot
        )

        #expect(
            probe.recordedEncodingInputs() == [
                EncoderInput(
                    renderResult: fixture.renderResult,
                    settings: fixture.request.jpegSettings
                )
            ]
        )
    }

    @Test func advanceRejectionStopsBeforeRenderAndEncoding() async throws {
        let fixture = try Self.makeFixture()
        let rejection = SimulationAdvanceRejection.cursorMismatch(
            expected: fixture.advanceResult.initialCursor,
            current: fixture.advanceResult.finalCursor
        )
        let probe = Probe()
        let advanceTarget = ScriptedAdvanceTarget(
            scripts: [.immediate(.rejected(rejection))],
            probe: probe
        )
        let renderTarget = ScriptedRenderTarget(scripts: [], probe: probe)
        let coordinator = Self.coordinator(
            advanceTarget: advanceTarget,
            renderTarget: renderTarget,
            probe: probe
        )

        let outcome = await coordinator.capture(fixture.request)

        #expect(outcome == .advanceRejected(rejection))
        #expect(await advanceTarget.requestCount() == 1)
        #expect(await renderTarget.requestCount() == 0)
        #expect(probe.recordedEncodingInputs().isEmpty)
        #expect(probe.recordedStages() == [.advance])
    }

    @Test func everyRenderTerminalPreservesOneExactAdvance() async throws {
        let fixture = try Self.makeFixture()
        let rejection = OffscreenRenderRejection.runtimeBusy
        try await Self.expectRenderTerminal(
            fixture: fixture,
            renderOutcome: .rejected(rejection),
            expected: .renderRejected(
                advanceResult: fixture.advanceResult,
                rejection: rejection
            )
        )

        let failure = OffscreenRenderFailure(
            stage: .gpuExecution,
            backendDescription: "scripted GPU failure"
        )
        try await Self.expectRenderTerminal(
            fixture: fixture,
            renderOutcome: .failed(failure),
            expected: .renderFailed(
                advanceResult: fixture.advanceResult,
                failure: failure
            )
        )

        try await Self.expectRenderTerminal(
            fixture: fixture,
            renderOutcome: .cancelledAfterSubmission(
                requestID: fixture.request.renderRequestID
            ),
            expected: .renderCancelledAfterSubmission(
                advanceResult: fixture.advanceResult,
                requestID: fixture.request.renderRequestID
            )
        )
    }

    @Test func jpegFailureRetainsAdvanceAndRawResultWithoutRetry() async throws {
        let fixture = try Self.makeFixture()
        let failure = JPEGArtifactEncoderError.destinationFinalizationFailed
        let probe = Probe(encodingResults: [.failure(failure)])
        let advanceTarget = ScriptedAdvanceTarget(
            scripts: [.immediate(.completed(fixture.advanceResult))],
            probe: probe
        )
        let renderTarget = ScriptedRenderTarget(
            scripts: [.immediate(.completed(fixture.renderResult))],
            probe: probe
        )
        let coordinator = Self.coordinator(
            advanceTarget: advanceTarget,
            renderTarget: renderTarget,
            probe: probe
        )

        let outcome = await coordinator.capture(fixture.request)

        #expect(
            outcome == .jpegEncodingFailed(
                advanceResult: fixture.advanceResult,
                renderResult: fixture.renderResult,
                failure: failure
            )
        )
        #expect(await advanceTarget.requestCount() == 1)
        #expect(await renderTarget.requestCount() == 1)
        #expect(probe.recordedEncodingInputs().count == 1)
        #expect(probe.recordedStages() == [.advance, .render, .encode])
    }

    @Test func provenanceMismatchNeverReachesEncoder() async throws {
        let fixture = try Self.makeFixture()
        let wrongCursor = SimulationCursor(
            sessionID: fixture.advanceResult.finalCursor.sessionID,
            tick: fixture.advanceResult.finalCursor.tick.advanced()
        )
        let wrongViewpoint = RenderViewpoint(
            id: fixture.request.viewpoint.id,
            revision: fixture.request.viewpoint.revision.advanced(),
            camera: fixture.request.viewpoint.camera
        )
        let wrongSettings = OffscreenRenderSettings(
            size: fixture.request.renderSettings.size,
            outputMode: .surface,
            exposure: ManualExposure(multiplier: 0.5)
        )
        let mismatches = [
            OffscreenRenderResult(
                requestID: OffscreenRenderRequestID(
                    rawValue: UUID(
                        uuidString: "00000000-0000-0000-0000-000000000499"
                    )!
                ),
                sourceCursor: fixture.renderResult.sourceCursor,
                viewpoint: fixture.renderResult.viewpoint,
                settings: fixture.renderResult.settings,
                image: fixture.renderResult.image
            ),
            OffscreenRenderResult(
                requestID: fixture.renderResult.requestID,
                sourceCursor: wrongCursor,
                viewpoint: fixture.renderResult.viewpoint,
                settings: fixture.renderResult.settings,
                image: fixture.renderResult.image
            ),
            OffscreenRenderResult(
                requestID: fixture.renderResult.requestID,
                sourceCursor: fixture.renderResult.sourceCursor,
                viewpoint: wrongViewpoint,
                settings: fixture.renderResult.settings,
                image: fixture.renderResult.image
            ),
            OffscreenRenderResult(
                requestID: fixture.renderResult.requestID,
                sourceCursor: fixture.renderResult.sourceCursor,
                viewpoint: fixture.renderResult.viewpoint,
                settings: wrongSettings,
                image: fixture.renderResult.image
            )
        ]

        for mismatch in mismatches {
            let probe = Probe()
            let advanceTarget = ScriptedAdvanceTarget(
                scripts: [.immediate(.completed(fixture.advanceResult))],
                probe: probe
            )
            let renderTarget = ScriptedRenderTarget(
                scripts: [.immediate(.completed(mismatch))],
                probe: probe
            )
            let coordinator = Self.coordinator(
                advanceTarget: advanceTarget,
                renderTarget: renderTarget,
                probe: probe
            )

            let outcome = await coordinator.capture(fixture.request)

            #expect(
                outcome == .renderResultMismatch(
                    advanceResult: fixture.advanceResult,
                    renderResult: mismatch
                )
            )
            #expect(await advanceTarget.requestCount() == 1)
            #expect(await renderTarget.requestCount() == 1)
            #expect(probe.recordedEncodingInputs().isEmpty)
            #expect(probe.recordedStages() == [.advance, .render])
        }
    }

    @Test func cancelledBeforeAdvanceDoesNoWork() async throws {
        let fixture = try Self.makeFixture()
        let probe = Probe()
        let advanceTarget = ScriptedAdvanceTarget(scripts: [], probe: probe)
        let renderTarget = ScriptedRenderTarget(scripts: [], probe: probe)
        let coordinator = Self.coordinator(
            advanceTarget: advanceTarget,
            renderTarget: renderTarget,
            probe: probe
        )

        let captureTask = Task {
            withUnsafeCurrentTask { task in
                task?.cancel()
            }
            return await coordinator.capture(fixture.request)
        }
        let outcome = await captureTask.value

        #expect(outcome == .cancelledBeforeAdvance)
        #expect(await advanceTarget.requestCount() == 0)
        #expect(await renderTarget.requestCount() == 0)
        #expect(probe.recordedStages().isEmpty)
    }

    @Test func cancellationAfterBlockedAdvanceRetainsCommittedResult() async throws {
        let fixture = try Self.makeFixture()
        let probe = Probe()
        let advanceTarget = ScriptedAdvanceTarget(
            scripts: [.suspended],
            probe: probe
        )
        let renderTarget = ScriptedRenderTarget(scripts: [], probe: probe)
        let coordinator = Self.coordinator(
            advanceTarget: advanceTarget,
            renderTarget: renderTarget,
            probe: probe
        )
        let captureTask = Task {
            await coordinator.capture(fixture.request)
        }

        await advanceTarget.waitForRequestCount(1)
        captureTask.cancel()
        await advanceTarget.resumeNext(with: .completed(fixture.advanceResult))
        let outcome = await captureTask.value

        #expect(outcome == .cancelledAfterAdvance(fixture.advanceResult))
        #expect(await advanceTarget.requestCount() == 1)
        #expect(await renderTarget.requestCount() == 0)
        #expect(probe.recordedEncodingInputs().isEmpty)
        #expect(probe.recordedStages() == [.advance])
    }

    @Test func cancellationAfterRawRenderRetainsBothCompletedPredecessors() async throws {
        let fixture = try Self.makeFixture()
        let probe = Probe()
        let advanceTarget = ScriptedAdvanceTarget(
            scripts: [.immediate(.completed(fixture.advanceResult))],
            probe: probe
        )
        let renderTarget = ScriptedRenderTarget(
            scripts: [.suspended],
            probe: probe
        )
        let coordinator = Self.coordinator(
            advanceTarget: advanceTarget,
            renderTarget: renderTarget,
            probe: probe
        )
        let captureTask = Task {
            await coordinator.capture(fixture.request)
        }

        await renderTarget.waitForRequestCount(1)
        captureTask.cancel()
        await renderTarget.resumeNext(with: .completed(fixture.renderResult))
        let outcome = await captureTask.value

        #expect(
            outcome == .cancelledAfterRender(
                advanceResult: fixture.advanceResult,
                renderResult: fixture.renderResult
            )
        )
        #expect(await advanceTarget.requestCount() == 1)
        #expect(await renderTarget.requestCount() == 1)
        #expect(probe.recordedEncodingInputs().isEmpty)
        #expect(probe.recordedStages() == [.advance, .render])
    }

    @Test func concurrentSecondRequestReturnsBusyWithoutWaiting() async throws {
        let fixture = try Self.makeFixture()
        let probe = Probe()
        let advanceTarget = ScriptedAdvanceTarget(
            scripts: [.suspended],
            probe: probe
        )
        let renderTarget = ScriptedRenderTarget(scripts: [], probe: probe)
        let coordinator = Self.coordinator(
            advanceTarget: advanceTarget,
            renderTarget: renderTarget,
            probe: probe
        )
        let firstTask = Task {
            await coordinator.capture(fixture.request)
        }

        await advanceTarget.waitForRequestCount(1)

        // This await completes while the first target continuation is still
        // suspended, proving typed backpressure rather than mailbox queuing.
        let secondOutcome = await coordinator.capture(fixture.request)
        #expect(secondOutcome == .coordinatorBusy)
        #expect(await advanceTarget.requestCount() == 1)

        firstTask.cancel()
        await advanceTarget.resumeNext(with: .completed(fixture.advanceResult))
        let firstOutcome = await firstTask.value
        #expect(firstOutcome == .cancelledAfterAdvance(fixture.advanceResult))
        #expect(await renderTarget.requestCount() == 0)
        #expect(probe.recordedStages() == [.advance])
    }

    private static func expectRenderTerminal(
        fixture: Fixture,
        renderOutcome: OffscreenRenderOutcome,
        expected: OfflineCaptureOutcome
    ) async throws {
        let probe = Probe()
        let advanceTarget = ScriptedAdvanceTarget(
            scripts: [.immediate(.completed(fixture.advanceResult))],
            probe: probe
        )
        let renderTarget = ScriptedRenderTarget(
            scripts: [.immediate(renderOutcome)],
            probe: probe
        )
        let coordinator = Self.coordinator(
            advanceTarget: advanceTarget,
            renderTarget: renderTarget,
            probe: probe
        )

        let outcome = await coordinator.capture(fixture.request)

        #expect(outcome == expected)
        #expect(await advanceTarget.requestCount() == 1)
        #expect(await renderTarget.requestCount() == 1)
        #expect(await renderTarget.recordedRequests() == [fixture.renderRequest])
        #expect(probe.recordedEncodingInputs().isEmpty)
        #expect(probe.recordedStages() == [.advance, .render])
    }

    private static func coordinator(
        advanceTarget: ScriptedAdvanceTarget,
        renderTarget: ScriptedRenderTarget,
        probe: Probe
    ) -> OfflineCaptureCoordinator {
        OfflineCaptureCoordinator(
            advanceTarget: advanceTarget,
            renderTarget: renderTarget,
            encodeJPEG: { renderResult, settings in
                probe.encode(renderResult, settings: settings)
            }
        )
    }

    private static func makeFixture() throws -> Fixture {
        let sessionID = SimulationSessionID(
            rawValue: UUID(
                uuidString: "00000000-0000-0000-0000-000000000401"
            )!
        )
        let initialCursor = SimulationCursor(
            sessionID: sessionID,
            tick: SimulationTick(rawValue: 10)
        )
        let finalCursor = SimulationCursor(
            sessionID: sessionID,
            tick: SimulationTick(rawValue: 13)
        )
        let snapshot = SimulationPresentationSnapshot(
            cursor: finalCursor,
            camera: Camera(
                position: SIMD3<Float>(2, 4, 8),
                orthographicHeight: 9,
                nearPlane: 0.2,
                farPlane: 90
            ),
            entityPresentations: [
                EntityPresentationSnapshot(
                    id: EntityID(index: 17, generation: 2),
                    position: SIMD3<Float>(1, 2, 3),
                    rotation: Transform.identityRotation,
                    scale: SIMD3<Float>(repeating: 1.5),
                    meshID: .ball,
                    materialID: .goldMetal
                )
            ]
        )
        let advanceResult = SimulationAdvanceResult(
            initialCursor: initialCursor,
            finalCursor: finalCursor,
            completedStepCount: SimulationCompletedStepCount(rawValue: 3),
            finalPresentationSnapshot: snapshot
        )
        let viewpoint = RenderViewpoint(
            id: RenderViewpointID(
                rawValue: UUID(
                    uuidString: "00000000-0000-0000-0000-000000000402"
                )!
            ),
            revision: RenderViewpointRevision(rawValue: 7),
            camera: Camera(position: SIMD3<Float>(6, 5, 4))
        )
        let size = try RenderPixelSize(width: 4, height: 3)
        let renderSettings = OffscreenRenderSettings(
            size: size,
            outputMode: .viewSpaceNormals,
            exposure: ManualExposure(multiplier: 1.25)
        )
        let jpegSettings = JPEGEncodingSettings(
            quality: try JPEGQuality(0.76)
        )
        let renderRequestID = OffscreenRenderRequestID(
            rawValue: UUID(
                uuidString: "00000000-0000-0000-0000-000000000403"
            )!
        )
        let request = OfflineCaptureRequest(
            advanceRequest: SimulationAdvanceRequest(
                expectedCursor: initialCursor,
                stepCount: SimulationStepCount(rawValue: 3),
                inputAssignment: .none
            ),
            renderRequestID: renderRequestID,
            viewpoint: viewpoint,
            renderSettings: renderSettings,
            jpegSettings: jpegSettings
        )
        let renderRequest = OffscreenRenderRequest(
            id: renderRequestID,
            presentationSnapshot: snapshot,
            viewpoint: viewpoint,
            settings: renderSettings
        )
        let image = try RenderedBGRA8SRGBImage(
            size: size,
            bytes: Data(repeating: 0x7F, count: size.pixelCount * 4)
        )
        let renderResult = OffscreenRenderResult(
            requestID: renderRequestID,
            sourceCursor: finalCursor,
            viewpoint: viewpoint,
            settings: renderSettings,
            image: image
        )
        let artifact = RenderedImageArtifact(
            format: .jpeg,
            encodedData: Data([0xFF, 0xD8, 0x41, 0xFF, 0xD9]),
            sourceRequestID: renderRequestID,
            sourceCursor: finalCursor,
            viewpoint: viewpoint,
            renderSettings: renderSettings,
            jpegSettings: jpegSettings
        )

        return Fixture(
            request: request,
            advanceResult: advanceResult,
            renderRequest: renderRequest,
            renderResult: renderResult,
            artifact: artifact
        )
    }

    private struct Fixture: Sendable {
        let request: OfflineCaptureRequest
        let advanceResult: SimulationAdvanceResult
        let renderRequest: OffscreenRenderRequest
        let renderResult: OffscreenRenderResult
        let artifact: RenderedImageArtifact
    }

    private enum Stage: Equatable, Sendable {
        case advance
        case render
        case encode
    }

    private struct EncoderInput: Equatable, Sendable {
        let renderResult: OffscreenRenderResult
        let settings: JPEGEncodingSettings
    }

    nonisolated private final class Probe: @unchecked Sendable {
        private let lock = NSLock()
        private var stages: [Stage] = []
        private var encodingInputs: [EncoderInput] = []
        private var encodingResults: [
            Result<RenderedImageArtifact, JPEGArtifactEncoderError>
        ]

        init(
            encodingResults: [
                Result<RenderedImageArtifact, JPEGArtifactEncoderError>
            ] = []
        ) {
            self.encodingResults = encodingResults
        }

        func record(_ stage: Stage) {
            lock.lock()
            stages.append(stage)
            lock.unlock()
        }

        func encode(
            _ renderResult: OffscreenRenderResult,
            settings: JPEGEncodingSettings
        ) -> Result<RenderedImageArtifact, JPEGArtifactEncoderError> {
            lock.lock()
            stages.append(.encode)
            encodingInputs.append(
                EncoderInput(renderResult: renderResult, settings: settings)
            )
            let result = encodingResults.isEmpty
                ? nil
                : encodingResults.removeFirst()
            lock.unlock()

            guard let result else {
                Issue.record("JPEG encoder was invoked unexpectedly.")
                return .failure(.couldNotCreateImage)
            }
            return result
        }

        func recordedStages() -> [Stage] {
            lock.lock()
            let result = stages
            lock.unlock()
            return result
        }

        func recordedEncodingInputs() -> [EncoderInput] {
            lock.lock()
            let result = encodingInputs
            lock.unlock()
            return result
        }
    }

    private actor ScriptedAdvanceTarget: PSimulationAdvanceTarget {
        enum Script: Sendable {
            case immediate(SimulationAdvanceOutcome)
            case suspended
        }

        private struct CountWaiter {
            let count: Int
            let continuation: CheckedContinuation<Void, Never>
        }

        private let probe: Probe
        private var scripts: [Script]
        private var requests: [SimulationAdvanceRequest] = []
        private var suspended: [
            CheckedContinuation<SimulationAdvanceOutcome, Never>
        ] = []
        private var countWaiters: [CountWaiter] = []

        init(scripts: [Script], probe: Probe) {
            self.scripts = scripts
            self.probe = probe
        }

        func advance(
            _ request: SimulationAdvanceRequest
        ) async -> SimulationAdvanceOutcome {
            probe.record(.advance)
            requests.append(request)
            notifyCountWaiters()

            guard !scripts.isEmpty else {
                Issue.record("Simulation advanced more times than scripted.")
                let cursor = request.expectedCursor ?? SimulationCursor(
                    sessionID: SimulationSessionID(),
                    tick: .zero
                )
                return .rejected(
                    .cursorMismatch(expected: cursor, current: cursor)
                )
            }

            switch scripts.removeFirst() {
            case let .immediate(outcome):
                return outcome

            case .suspended:
                return await withCheckedContinuation { continuation in
                    suspended.append(continuation)
                }
            }
        }

        func requestCount() -> Int {
            requests.count
        }

        func recordedRequests() -> [SimulationAdvanceRequest] {
            requests
        }

        func waitForRequestCount(_ count: Int) async {
            guard requests.count < count else {
                return
            }
            await withCheckedContinuation { continuation in
                countWaiters.append(
                    CountWaiter(count: count, continuation: continuation)
                )
            }
        }

        func resumeNext(with outcome: SimulationAdvanceOutcome) {
            guard !suspended.isEmpty else {
                Issue.record("No suspended Simulation advance was pending.")
                return
            }
            suspended.removeFirst().resume(returning: outcome)
        }

        private func notifyCountWaiters() {
            var remaining: [CountWaiter] = []
            for waiter in countWaiters {
                if requests.count >= waiter.count {
                    waiter.continuation.resume()
                } else {
                    remaining.append(waiter)
                }
            }
            countWaiters = remaining
        }
    }

    private actor ScriptedRenderTarget: POffscreenRenderTarget {
        enum Script: Sendable {
            case immediate(OffscreenRenderOutcome)
            case suspended
        }

        private struct CountWaiter {
            let count: Int
            let continuation: CheckedContinuation<Void, Never>
        }

        private let probe: Probe
        private var scripts: [Script]
        private var requests: [OffscreenRenderRequest] = []
        private var suspended: [
            CheckedContinuation<OffscreenRenderOutcome, Never>
        ] = []
        private var countWaiters: [CountWaiter] = []

        init(scripts: [Script], probe: Probe) {
            self.scripts = scripts
            self.probe = probe
        }

        func render(
            _ request: OffscreenRenderRequest
        ) async -> OffscreenRenderOutcome {
            probe.record(.render)
            requests.append(request)
            notifyCountWaiters()

            guard !scripts.isEmpty else {
                Issue.record("Offscreen rendering ran more times than scripted.")
                return .rejected(.runtimeBusy)
            }

            switch scripts.removeFirst() {
            case let .immediate(outcome):
                return outcome

            case .suspended:
                return await withCheckedContinuation { continuation in
                    suspended.append(continuation)
                }
            }
        }

        func requestCount() -> Int {
            requests.count
        }

        func recordedRequests() -> [OffscreenRenderRequest] {
            requests
        }

        func waitForRequestCount(_ count: Int) async {
            guard requests.count < count else {
                return
            }
            await withCheckedContinuation { continuation in
                countWaiters.append(
                    CountWaiter(count: count, continuation: continuation)
                )
            }
        }

        func resumeNext(with outcome: OffscreenRenderOutcome) {
            guard !suspended.isEmpty else {
                Issue.record("No suspended offscreen render was pending.")
                return
            }
            suspended.removeFirst().resume(returning: outcome)
        }

        private func notifyCountWaiters() {
            var remaining: [CountWaiter] = []
            for waiter in countWaiters {
                if requests.count >= waiter.count {
                    waiter.continuation.resume()
                } else {
                    remaining.append(waiter)
                }
            }
            countWaiters = remaining
        }
    }
}
