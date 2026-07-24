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
            initialPresentationSnapshot: fixture.initialSnapshot,
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
            initialPresentationSnapshot: fixture.initialSnapshot,
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

    @Test func mismatchedCompletedRangeBecomesCurrentWithoutRendering() async throws {
        let fixture = try Self.makeFixture()
        let returnedFinalCursor = fixture.initialSnapshot.cursor
            .advanced()
            .advanced()
        let returnedFinalSnapshot = SimulationPresentationSnapshot(
            cursor: returnedFinalCursor,
            camera: Camera(
                position: SIMD3<Float>(3, 5, 9),
                orthographicHeight: 11,
                nearPlane: 0.25,
                farPlane: 110
            ),
            entityPresentations: []
        )
        let mismatchedResult = SimulationAdvanceResult(
            initialCursor: fixture.initialSnapshot.cursor,
            finalCursor: returnedFinalCursor,
            completedStepCount: SimulationCompletedStepCount(rawValue: 2),
            finalPresentationSnapshot: returnedFinalSnapshot
        )
        let currentRequest = Self.currentRequest(
            for: fixture,
            expectedCursor: returnedFinalCursor
        )
        let currentRenderResult = Self.currentRenderResult(
            sourceSnapshot: returnedFinalSnapshot,
            request: currentRequest,
            image: fixture.renderResult.image
        )
        let currentArtifact = Self.currentArtifact(
            sourceSnapshot: returnedFinalSnapshot,
            request: currentRequest
        )
        let probe = Probe(encodingResults: [.success(currentArtifact)])
        let advanceTarget = ScriptedAdvanceTarget(
            scripts: [.immediate(.completed(mismatchedResult))],
            probe: probe
        )
        let renderTarget = ScriptedRenderTarget(
            scripts: [.immediate(.completed(currentRenderResult))],
            probe: probe
        )
        let coordinator = Self.coordinator(
            advanceTarget: advanceTarget,
            initialPresentationSnapshot: fixture.initialSnapshot,
            renderTarget: renderTarget,
            probe: probe
        )

        let advanceOutcome = await coordinator.capture(fixture.request)

        #expect(
            advanceOutcome == .advanceResultMismatch(
                coordinatorCursor: fixture.initialSnapshot.cursor,
                requestedExpectedCursor:
                    fixture.request.advanceRequest.expectedCursor,
                requestedStepCount: fixture.request.advanceRequest.stepCount,
                result: mismatchedResult
            )
        )
        #expect(await advanceTarget.requestCount() == 1)
        #expect(await renderTarget.requestCount() == 0)
        #expect(probe.recordedEncodingInputs().isEmpty)
        #expect(probe.recordedStages() == [.advance])

        let currentOutcome = await coordinator.captureCurrent(currentRequest)

        #expect(
            currentOutcome == .completed(
                OfflineCurrentCaptureResult(
                    sourceSnapshot: returnedFinalSnapshot,
                    artifact: currentArtifact
                )
            )
        )
        #expect(await advanceTarget.requestCount() == 1)
        #expect(
            await renderTarget.recordedRequests() == [
                OffscreenRenderRequest(
                    id: currentRequest.renderRequestID,
                    presentationSnapshot: returnedFinalSnapshot,
                    viewpoint: currentRequest.viewpoint,
                    settings: currentRequest.renderSettings
                )
            ]
        )
        #expect(
            probe.recordedEncodingInputs() == [
                EncoderInput(
                    renderResult: currentRenderResult,
                    settings: currentRequest.jpegSettings
                )
            ]
        )
        #expect(probe.recordedStages() == [.advance, .render, .encode])
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

    @Test func renderCancellationWithWrongRequestIDReturnsTypedMismatch() async throws {
        let fixture = try Self.makeFixture()
        let wrongRequestID = OffscreenRenderRequestID(
            rawValue: UUID(
                uuidString: "00000000-0000-0000-0000-000000000498"
            )!
        )

        try await Self.expectRenderTerminal(
            fixture: fixture,
            renderOutcome: .cancelledAfterSubmission(
                requestID: wrongRequestID
            ),
            expected: .renderCancellationRequestIDMismatch(
                advanceResult: fixture.advanceResult,
                expectedRequestID: fixture.request.renderRequestID,
                actualRequestID: wrongRequestID
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
            initialPresentationSnapshot: fixture.initialSnapshot,
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
        let wrongImageSize = try RenderPixelSize(width: 5, height: 3)
        let wrongSizedImage = try RenderedBGRA8SRGBImage(
            size: wrongImageSize,
            bytes: Data(
                repeating: 0x5A,
                count: wrongImageSize.pixelCount * 4
            )
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
            ),
            OffscreenRenderResult(
                requestID: fixture.renderResult.requestID,
                sourceCursor: fixture.renderResult.sourceCursor,
                viewpoint: fixture.renderResult.viewpoint,
                settings: fixture.renderResult.settings,
                image: wrongSizedImage
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
                initialPresentationSnapshot: fixture.initialSnapshot,
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
            initialPresentationSnapshot: fixture.initialSnapshot,
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
            initialPresentationSnapshot: fixture.initialSnapshot,
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
            initialPresentationSnapshot: fixture.initialSnapshot,
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
            initialPresentationSnapshot: fixture.initialSnapshot,
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

    @Test func concurrentSecondRequestReturnsBusyWhileJPEGIsSuspended() async throws {
        let fixture = try Self.makeFixture()
        let probe = Probe()
        let suspendedEncoder = SuspendedEncoder(probe: probe)
        let advanceTarget = ScriptedAdvanceTarget(
            scripts: [.immediate(.completed(fixture.advanceResult))],
            probe: probe
        )
        let renderTarget = ScriptedRenderTarget(
            scripts: [.immediate(.completed(fixture.renderResult))],
            probe: probe
        )
        let coordinator = OfflineCaptureCoordinator(
            advanceTarget: advanceTarget,
            initialPresentationSnapshot: fixture.initialSnapshot,
            renderTarget: renderTarget,
            encodeJPEG: { renderResult, settings in
                await suspendedEncoder.encode(
                    renderResult,
                    settings: settings
                )
            }
        )
        let firstTask = Task {
            await coordinator.capture(fixture.request)
        }

        await suspendedEncoder.waitForCallCount(1)

        // Encoding is still suspended, so this return proves the explicit gate
        // spans async artifact work instead of releasing at the render boundary.
        let secondOutcome = await coordinator.capture(fixture.request)
        #expect(secondOutcome == .coordinatorBusy)
        #expect(await advanceTarget.requestCount() == 1)
        #expect(await renderTarget.requestCount() == 1)
        #expect(await suspendedEncoder.callCount() == 1)

        await suspendedEncoder.resumeNext(with: .success(fixture.artifact))
        let firstOutcome = await firstTask.value

        #expect(
            firstOutcome == .completed(
                OfflineCaptureResult(
                    advanceResult: fixture.advanceResult,
                    artifact: fixture.artifact
                )
            )
        )
        #expect(await advanceTarget.requestCount() == 1)
        #expect(await renderTarget.requestCount() == 1)
        #expect(await suspendedEncoder.callCount() == 1)
        #expect(
            await suspendedEncoder.recordedInputs() == [
                EncoderInput(
                    renderResult: fixture.renderResult,
                    settings: fixture.request.jpegSettings
                )
            ]
        )
        #expect(probe.recordedStages() == [.advance, .render, .encode])
    }

    @Test func capturesInitialCurrentSnapshotWithoutAdvancing() async throws {
        let fixture = try Self.makeFixture()
        let request = Self.currentRequest(for: fixture)
        let renderResult = Self.currentRenderResult(
            sourceSnapshot: fixture.initialSnapshot,
            request: request,
            image: fixture.renderResult.image
        )
        let artifact = Self.currentArtifact(
            sourceSnapshot: fixture.initialSnapshot,
            request: request
        )
        let probe = Probe(encodingResults: [.success(artifact)])
        let advanceTarget = ScriptedAdvanceTarget(scripts: [], probe: probe)
        let renderTarget = ScriptedRenderTarget(
            scripts: [.immediate(.completed(renderResult))],
            probe: probe
        )
        let coordinator = Self.coordinator(
            advanceTarget: advanceTarget,
            initialPresentationSnapshot: fixture.initialSnapshot,
            renderTarget: renderTarget,
            probe: probe
        )

        let outcome = await coordinator.captureCurrent(request)

        #expect(
            outcome == .completed(
                OfflineCurrentCaptureResult(
                    sourceSnapshot: fixture.initialSnapshot,
                    artifact: artifact
                )
            )
        )
        #expect(await advanceTarget.requestCount() == 0)
        #expect(
            await renderTarget.recordedRequests() == [
                OffscreenRenderRequest(
                    id: request.renderRequestID,
                    presentationSnapshot: fixture.initialSnapshot,
                    viewpoint: request.viewpoint,
                    settings: request.renderSettings
                )
            ]
        )
        #expect(
            probe.recordedEncodingInputs() == [
                EncoderInput(
                    renderResult: renderResult,
                    settings: request.jpegSettings
                )
            ]
        )
        #expect(probe.recordedStages() == [.render, .encode])
    }

    @Test func currentCursorMismatchStopsBeforeRenderAndEncoding() async throws {
        let fixture = try Self.makeFixture()
        let request = Self.currentRequest(
            for: fixture,
            expectedCursor: fixture.advanceResult.finalCursor
        )
        let probe = Probe()
        let advanceTarget = ScriptedAdvanceTarget(scripts: [], probe: probe)
        let renderTarget = ScriptedRenderTarget(scripts: [], probe: probe)
        let coordinator = Self.coordinator(
            advanceTarget: advanceTarget,
            initialPresentationSnapshot: fixture.initialSnapshot,
            renderTarget: renderTarget,
            probe: probe
        )

        let outcome = await coordinator.captureCurrent(request)

        #expect(
            outcome == .cursorMismatch(
                expected: fixture.advanceResult.finalCursor,
                current: fixture.initialSnapshot.cursor
            )
        )
        #expect(await advanceTarget.requestCount() == 0)
        #expect(await renderTarget.requestCount() == 0)
        #expect(probe.recordedEncodingInputs().isEmpty)
        #expect(probe.recordedStages().isEmpty)
    }

    @Test func cancelledBeforeCurrentRenderDoesNoWork() async throws {
        let fixture = try Self.makeFixture()
        let request = Self.currentRequest(for: fixture)
        let probe = Probe()
        let advanceTarget = ScriptedAdvanceTarget(scripts: [], probe: probe)
        let renderTarget = ScriptedRenderTarget(scripts: [], probe: probe)
        let coordinator = Self.coordinator(
            advanceTarget: advanceTarget,
            initialPresentationSnapshot: fixture.initialSnapshot,
            renderTarget: renderTarget,
            probe: probe
        )

        let currentTask = Task {
            withUnsafeCurrentTask { task in
                task?.cancel()
            }
            return await coordinator.captureCurrent(request)
        }

        #expect(await currentTask.value == .cancelledBeforeRender)
        #expect(await advanceTarget.requestCount() == 0)
        #expect(await renderTarget.requestCount() == 0)
        #expect(probe.recordedStages().isEmpty)
    }

    @Test func currentRenderCancellationIDMismatchPreservesSnapshot() async throws {
        let fixture = try Self.makeFixture()
        let request = Self.currentRequest(for: fixture)
        let wrongRequestID = OffscreenRenderRequestID(
            rawValue: UUID(
                uuidString: "00000000-0000-0000-0000-000000000497"
            )!
        )
        let probe = Probe()
        let advanceTarget = ScriptedAdvanceTarget(scripts: [], probe: probe)
        let renderTarget = ScriptedRenderTarget(
            scripts: [
                .immediate(
                    .cancelledAfterSubmission(requestID: wrongRequestID)
                )
            ],
            probe: probe
        )
        let coordinator = Self.coordinator(
            advanceTarget: advanceTarget,
            initialPresentationSnapshot: fixture.initialSnapshot,
            renderTarget: renderTarget,
            probe: probe
        )

        let outcome = await coordinator.captureCurrent(request)

        #expect(
            outcome == .renderCancellationRequestIDMismatch(
                sourceSnapshot: fixture.initialSnapshot,
                expectedRequestID: request.renderRequestID,
                actualRequestID: wrongRequestID
            )
        )
        #expect(await advanceTarget.requestCount() == 0)
        #expect(probe.recordedEncodingInputs().isEmpty)
        #expect(probe.recordedStages() == [.render])
    }

    @Test func currentRenderResultMismatchPreservesSnapshotAndRawValue() async throws {
        let fixture = try Self.makeFixture()
        let request = Self.currentRequest(for: fixture)
        let mismatch = OffscreenRenderResult(
            requestID: request.renderRequestID,
            sourceCursor: fixture.advanceResult.finalCursor,
            viewpoint: request.viewpoint,
            settings: request.renderSettings,
            image: fixture.renderResult.image
        )
        let probe = Probe()
        let advanceTarget = ScriptedAdvanceTarget(scripts: [], probe: probe)
        let renderTarget = ScriptedRenderTarget(
            scripts: [.immediate(.completed(mismatch))],
            probe: probe
        )
        let coordinator = Self.coordinator(
            advanceTarget: advanceTarget,
            initialPresentationSnapshot: fixture.initialSnapshot,
            renderTarget: renderTarget,
            probe: probe
        )

        let outcome = await coordinator.captureCurrent(request)

        #expect(
            outcome == .renderResultMismatch(
                sourceSnapshot: fixture.initialSnapshot,
                renderResult: mismatch
            )
        )
        #expect(await advanceTarget.requestCount() == 0)
        #expect(probe.recordedEncodingInputs().isEmpty)
        #expect(probe.recordedStages() == [.render])
    }

    @Test func completedAdvanceBecomesCurrentBeforeRenderFailure() async throws {
        let fixture = try Self.makeFixture()
        let currentRequest = Self.currentRequest(
            for: fixture,
            expectedCursor: fixture.advanceResult.finalCursor
        )
        let currentRenderResult = Self.currentRenderResult(
            sourceSnapshot: fixture.advanceResult.finalPresentationSnapshot,
            request: currentRequest,
            image: fixture.renderResult.image
        )
        let currentArtifact = Self.currentArtifact(
            sourceSnapshot: fixture.advanceResult.finalPresentationSnapshot,
            request: currentRequest
        )
        let renderFailure = OffscreenRenderFailure(
            stage: .gpuExecution,
            backendDescription: "first output failed after exact advance"
        )
        let probe = Probe(encodingResults: [.success(currentArtifact)])
        let advanceTarget = ScriptedAdvanceTarget(
            scripts: [.immediate(.completed(fixture.advanceResult))],
            probe: probe
        )
        let renderTarget = ScriptedRenderTarget(
            scripts: [
                .immediate(.failed(renderFailure)),
                .immediate(.completed(currentRenderResult))
            ],
            probe: probe
        )
        let coordinator = Self.coordinator(
            advanceTarget: advanceTarget,
            initialPresentationSnapshot: fixture.initialSnapshot,
            renderTarget: renderTarget,
            probe: probe
        )

        let advanceOutcome = await coordinator.capture(fixture.request)
        #expect(
            advanceOutcome == .renderFailed(
                advanceResult: fixture.advanceResult,
                failure: renderFailure
            )
        )

        let currentOutcome = await coordinator.captureCurrent(currentRequest)
        #expect(
            currentOutcome == .completed(
                OfflineCurrentCaptureResult(
                    sourceSnapshot: fixture.advanceResult.finalPresentationSnapshot,
                    artifact: currentArtifact
                )
            )
        )
        #expect(await advanceTarget.requestCount() == 1)
        let renderRequests = await renderTarget.recordedRequests()
        #expect(renderRequests.count == 2)
        #expect(
            renderRequests.last?.presentationSnapshot ==
            fixture.advanceResult.finalPresentationSnapshot
        )
        #expect(probe.recordedStages() == [.advance, .render, .render, .encode])
    }

    @Test func currentCaptureBlocksAdvanceAcrossTheSharedGate() async throws {
        let fixture = try Self.makeFixture()
        let request = Self.currentRequest(for: fixture)
        let renderResult = Self.currentRenderResult(
            sourceSnapshot: fixture.initialSnapshot,
            request: request,
            image: fixture.renderResult.image
        )
        let artifact = Self.currentArtifact(
            sourceSnapshot: fixture.initialSnapshot,
            request: request
        )
        let probe = Probe(encodingResults: [.success(artifact)])
        let advanceTarget = ScriptedAdvanceTarget(scripts: [], probe: probe)
        let renderTarget = ScriptedRenderTarget(
            scripts: [.suspended],
            probe: probe
        )
        let coordinator = Self.coordinator(
            advanceTarget: advanceTarget,
            initialPresentationSnapshot: fixture.initialSnapshot,
            renderTarget: renderTarget,
            probe: probe
        )
        let currentTask = Task {
            await coordinator.captureCurrent(request)
        }

        await renderTarget.waitForRequestCount(1)
        let advanceOutcome = await coordinator.capture(fixture.request)

        #expect(advanceOutcome == .coordinatorBusy)
        #expect(await advanceTarget.requestCount() == 0)

        await renderTarget.resumeNext(with: .completed(renderResult))
        #expect(
            await currentTask.value == .completed(
                OfflineCurrentCaptureResult(
                    sourceSnapshot: fixture.initialSnapshot,
                    artifact: artifact
                )
            )
        )
        #expect(probe.recordedStages() == [.render, .encode])
    }

    @Test func advanceCaptureBlocksCurrentAcrossTheSharedGate() async throws {
        let fixture = try Self.makeFixture()
        let currentRequest = Self.currentRequest(for: fixture)
        let probe = Probe()
        let advanceTarget = ScriptedAdvanceTarget(
            scripts: [.suspended],
            probe: probe
        )
        let renderTarget = ScriptedRenderTarget(scripts: [], probe: probe)
        let coordinator = Self.coordinator(
            advanceTarget: advanceTarget,
            initialPresentationSnapshot: fixture.initialSnapshot,
            renderTarget: renderTarget,
            probe: probe
        )
        let advanceTask = Task {
            await coordinator.capture(fixture.request)
        }

        await advanceTarget.waitForRequestCount(1)
        let currentOutcome = await coordinator.captureCurrent(currentRequest)

        #expect(currentOutcome == .coordinatorBusy)
        #expect(await renderTarget.requestCount() == 0)

        advanceTask.cancel()
        await advanceTarget.resumeNext(with: .completed(fixture.advanceResult))
        #expect(
            await advanceTask.value ==
            .cancelledAfterAdvance(fixture.advanceResult)
        )
    }

    @Test func currentCancellationAfterRawRenderRetainsExactPredecessors() async throws {
        let fixture = try Self.makeFixture()
        let request = Self.currentRequest(for: fixture)
        let renderResult = Self.currentRenderResult(
            sourceSnapshot: fixture.initialSnapshot,
            request: request,
            image: fixture.renderResult.image
        )
        let probe = Probe()
        let advanceTarget = ScriptedAdvanceTarget(scripts: [], probe: probe)
        let renderTarget = ScriptedRenderTarget(
            scripts: [.suspended],
            probe: probe
        )
        let coordinator = Self.coordinator(
            advanceTarget: advanceTarget,
            initialPresentationSnapshot: fixture.initialSnapshot,
            renderTarget: renderTarget,
            probe: probe
        )
        let currentTask = Task {
            await coordinator.captureCurrent(request)
        }

        await renderTarget.waitForRequestCount(1)
        currentTask.cancel()
        await renderTarget.resumeNext(with: .completed(renderResult))

        #expect(
            await currentTask.value == .cancelledAfterRender(
                sourceSnapshot: fixture.initialSnapshot,
                renderResult: renderResult
            )
        )
        #expect(await advanceTarget.requestCount() == 0)
        #expect(probe.recordedEncodingInputs().isEmpty)
        #expect(probe.recordedStages() == [.render])
    }

    @Test func currentJPEGFailureRetainsSnapshotAndRawResult() async throws {
        let fixture = try Self.makeFixture()
        let request = Self.currentRequest(for: fixture)
        let renderResult = Self.currentRenderResult(
            sourceSnapshot: fixture.initialSnapshot,
            request: request,
            image: fixture.renderResult.image
        )
        let failure = JPEGArtifactEncoderError.destinationFinalizationFailed
        let probe = Probe(encodingResults: [.failure(failure)])
        let advanceTarget = ScriptedAdvanceTarget(scripts: [], probe: probe)
        let renderTarget = ScriptedRenderTarget(
            scripts: [.immediate(.completed(renderResult))],
            probe: probe
        )
        let coordinator = Self.coordinator(
            advanceTarget: advanceTarget,
            initialPresentationSnapshot: fixture.initialSnapshot,
            renderTarget: renderTarget,
            probe: probe
        )

        let outcome = await coordinator.captureCurrent(request)

        #expect(
            outcome == .jpegEncodingFailed(
                sourceSnapshot: fixture.initialSnapshot,
                renderResult: renderResult,
                failure: failure
            )
        )
        #expect(await advanceTarget.requestCount() == 0)
        #expect(await renderTarget.requestCount() == 1)
        #expect(probe.recordedStages() == [.render, .encode])
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
            initialPresentationSnapshot: fixture.initialSnapshot,
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

    private static func currentRequest(
        for fixture: Fixture,
        expectedCursor: SimulationCursor? = nil
    ) -> OfflineCurrentCaptureRequest {
        OfflineCurrentCaptureRequest(
            expectedCursor: expectedCursor ?? fixture.initialSnapshot.cursor,
            viewpoint: fixture.request.viewpoint,
            renderSettings: fixture.request.renderSettings,
            jpegSettings: fixture.request.jpegSettings
        )
    }

    private static func currentRenderResult(
        sourceSnapshot: SimulationPresentationSnapshot,
        request: OfflineCurrentCaptureRequest,
        image: RenderedBGRA8SRGBImage
    ) -> OffscreenRenderResult {
        OffscreenRenderResult(
            requestID: request.renderRequestID,
            sourceCursor: sourceSnapshot.cursor,
            viewpoint: request.viewpoint,
            settings: request.renderSettings,
            image: image
        )
    }

    private static func currentArtifact(
        sourceSnapshot: SimulationPresentationSnapshot,
        request: OfflineCurrentCaptureRequest
    ) -> RenderedImageArtifact {
        RenderedImageArtifact(
            format: .jpeg,
            encodedData: Data([0xFF, 0xD8, 0x52, 0xFF, 0xD9]),
            sourceRequestID: request.renderRequestID,
            sourceCursor: sourceSnapshot.cursor,
            viewpoint: request.viewpoint,
            renderSettings: request.renderSettings,
            jpegSettings: request.jpegSettings
        )
    }

    private static func coordinator(
        advanceTarget: ScriptedAdvanceTarget,
        initialPresentationSnapshot: SimulationPresentationSnapshot,
        renderTarget: ScriptedRenderTarget,
        probe: Probe
    ) -> OfflineCaptureCoordinator {
        OfflineCaptureCoordinator(
            advanceTarget: advanceTarget,
            initialPresentationSnapshot: initialPresentationSnapshot,
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
        let initialSnapshot = SimulationPresentationSnapshot(
            cursor: initialCursor,
            camera: Camera(
                position: SIMD3<Float>(9, 8, 7),
                orthographicHeight: 12,
                nearPlane: 0.1,
                farPlane: 120
            ),
            entityPresentations: []
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
            initialSnapshot: initialSnapshot,
            advanceResult: advanceResult,
            renderRequest: renderRequest,
            renderResult: renderResult,
            artifact: artifact
        )
    }

    private struct Fixture: Sendable {
        let request: OfflineCaptureRequest
        let initialSnapshot: SimulationPresentationSnapshot
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

    private actor SuspendedEncoder {
        private struct CountWaiter {
            let count: Int
            let continuation: CheckedContinuation<Void, Never>
        }

        private let probe: Probe
        private var inputs: [EncoderInput] = []
        private var suspended: [
            CheckedContinuation<
                Result<RenderedImageArtifact, JPEGArtifactEncoderError>,
                Never
            >
        ] = []
        private var countWaiters: [CountWaiter] = []

        init(probe: Probe) {
            self.probe = probe
        }

        func encode(
            _ renderResult: OffscreenRenderResult,
            settings: JPEGEncodingSettings
        ) async -> Result<RenderedImageArtifact, JPEGArtifactEncoderError> {
            probe.record(.encode)
            inputs.append(
                EncoderInput(renderResult: renderResult, settings: settings)
            )
            notifyCountWaiters()

            return await withCheckedContinuation { continuation in
                suspended.append(continuation)
            }
        }

        func callCount() -> Int {
            inputs.count
        }

        func recordedInputs() -> [EncoderInput] {
            inputs
        }

        func waitForCallCount(_ count: Int) async {
            guard inputs.count < count else {
                return
            }
            await withCheckedContinuation { continuation in
                countWaiters.append(
                    CountWaiter(count: count, continuation: continuation)
                )
            }
        }

        func resumeNext(
            with result: Result<
                RenderedImageArtifact,
                JPEGArtifactEncoderError
            >
        ) {
            guard !suspended.isEmpty else {
                Issue.record("No suspended JPEG encoding was pending.")
                return
            }
            suspended.removeFirst().resume(returning: result)
        }

        private func notifyCountWaiters() {
            var remaining: [CountWaiter] = []
            for waiter in countWaiters {
                if inputs.count >= waiter.count {
                    waiter.continuation.resume()
                } else {
                    remaining.append(waiter)
                }
            }
            countWaiters = remaining
        }
    }
}
