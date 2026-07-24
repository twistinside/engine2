import Foundation
import simd
import Testing
@testable import Engine2

struct AgentSessionCoordinatorTests {
    @Test func sessionIdentitySupportsFreshRawAndCodableRoundTrips() throws {
        let rawValue = try #require(
            UUID(uuidString: "50000000-0000-0000-0000-000000000000")
        )
        let fixed = AgentSessionID(rawValue: rawValue)
        let firstFresh = AgentSessionID()
        let secondFresh = AgentSessionID()

        #expect(firstFresh != secondFresh)
        #expect(Self.rawRoundTrip(fixed) == fixed)

        let data = try JSONEncoder().encode(fixed)
        #expect(
            try JSONDecoder().decode(
                AgentSessionID.self,
                from: data
            ) == fixed
        )
    }

    @Test func requestSequencePreservesZeroOrdinaryAndMaximumValues() throws {
        let sequences = [
            AgentSessionRequestSequence.first,
            AgentSessionRequestSequence(rawValue: 42),
            AgentSessionRequestSequence(rawValue: .max - 1),
            AgentSessionRequestSequence(rawValue: .max)
        ]

        for sequence in sequences {
            #expect(Self.rawRoundTrip(sequence) == sequence)
            let data = try JSONEncoder().encode(sequence)
            #expect(
                try JSONDecoder().decode(
                    AgentSessionRequestSequence.self,
                    from: data
                ) == sequence
            )
        }

        #expect(sequences[0].rawValue == 0)
        #expect(sequences[0].successor()?.rawValue == 1)
        #expect(sequences[1].successor()?.rawValue == 43)
        #expect(sequences[2].successor()?.rawValue == .max)
        #expect(sequences[3].successor() == nil)
        #expect(sequences.sorted() == sequences)
    }

    @Test func validCommandMapsExactOfflineRequestAndForwardsOnce() async throws {
        let fixture = try Self.makeFixture()
        let request = fixture.request(sequence: 0)
        let target = ScriptedCaptureTarget(
            scripts: [.immediate(.cancelledBeforeAdvance)]
        )
        let coordinator = Self.coordinator(fixture: fixture, target: target)

        let response = try Self.executedResponse(
            from: await coordinator.capture(request)
        )

        #expect(response.requestID == request.id)
        #expect(response.knownCursor == fixture.initialCursor)
        #expect(response.outcome == .capture(.cancelledBeforeAdvance))

        let forwardedRequests = await target.recordedRequests()
        let forwarded = try #require(forwardedRequests.first)
        #expect(forwardedRequests.count == 1)
        guard case let .advance(expectedCursor, stepCount) = request.source else {
            Issue.record("Expected an advancing agent source.")
            return
        }
        #expect(
            forwarded.advanceRequest.expectedCursor == expectedCursor
        )
        #expect(forwarded.advanceRequest.stepCount == stepCount)
        guard case .none = forwarded.advanceRequest.inputAssignment else {
            Issue.record("Agent capture introduced an unexpected input assignment.")
            return
        }
        #expect(forwarded.renderRequestID == request.renderRequestID)
        #expect(forwarded.viewpoint == request.viewpoint)
        #expect(forwarded.renderSettings == request.renderSettings)
        #expect(forwarded.jpegSettings == request.jpegSettings)
    }

    @Test func currentCommandMapsExactRequestWithoutAdvancing() async throws {
        let fixture = try Self.makeFixture()
        let request = fixture.currentRequest(sequence: 0)
        let sourceSnapshot = fixture.snapshot(at: fixture.initialCursor)
        let completed = fixture.currentCompletedOutcome(
            request: request,
            sourceSnapshot: sourceSnapshot,
            encodedBytes: Data([0xFF, 0xD8, 0x44, 0xFF, 0xD9])
        )
        let target = ScriptedCaptureTarget(
            scripts: [.currentImmediate(completed)]
        )
        let coordinator = Self.coordinator(fixture: fixture, target: target)

        let response = try Self.executedResponse(
            from: await coordinator.capture(request)
        )

        #expect(response.outcome == .currentCapture(completed))
        #expect(response.knownCursor == fixture.initialCursor)
        #expect(await target.recordedRequests().isEmpty)

        let forwarded = try #require(
            await target.recordedCurrentRequests().first
        )
        #expect(forwarded.expectedCursor == fixture.initialCursor)
        #expect(forwarded.renderRequestID == request.renderRequestID)
        #expect(forwarded.viewpoint == request.viewpoint)
        #expect(forwarded.renderSettings == request.renderSettings)
        #expect(forwarded.jpegSettings == request.jpegSettings)
        #expect(await target.requestCount() == 1)
    }

    @Test func currentReplayAndChangedSourceShareOneIdentityLane() async throws {
        let fixture = try Self.makeFixture()
        let request = fixture.currentRequest(sequence: 0)
        let completed = fixture.currentCompletedOutcome(
            request: request,
            sourceSnapshot: fixture.snapshot(at: fixture.initialCursor),
            encodedBytes: Data([0xFF, 0xD8, 0x55, 0xFF, 0xD9])
        )
        let target = ScriptedCaptureTarget(
            scripts: [.currentImmediate(completed)]
        )
        let coordinator = Self.coordinator(fixture: fixture, target: target)

        let first = try Self.executedResponse(
            from: await coordinator.capture(request)
        )
        #expect(await coordinator.capture(request) == .replayed(first))

        let changedSource = AgentCaptureRequest(
            id: request.id,
            expectedCursor: fixture.initialCursor,
            stepCount: .one,
            renderRequestID: request.renderRequestID,
            viewpoint: request.viewpoint,
            renderSettings: request.renderSettings,
            jpegSettings: request.jpegSettings
        )
        #expect(
            await coordinator.capture(changedSource) == .rejected(
                AgentSessionRequestRejection(
                    reason: .requestConflict(request.id),
                    knownCursor: fixture.initialCursor
                )
            )
        )
        #expect(await target.requestCount() == 1)
    }

    @Test func inFlightCurrentConflictsWithAdvanceAtTheSameIdentity() async throws {
        let fixture = try Self.makeFixture()
        let currentRequest = fixture.currentRequest(sequence: 0)
        let changedSource = AgentCaptureRequest(
            id: currentRequest.id,
            expectedCursor: currentRequest.source.expectedCursor,
            stepCount: .one,
            renderRequestID: currentRequest.renderRequestID,
            viewpoint: currentRequest.viewpoint,
            renderSettings: currentRequest.renderSettings,
            jpegSettings: currentRequest.jpegSettings
        )
        let target = ScriptedCaptureTarget(scripts: [.currentSuspended])
        let coordinator = Self.coordinator(fixture: fixture, target: target)
        let acceptedTask = Task {
            await coordinator.capture(currentRequest)
        }
        await target.waitForRequestCount(1)

        #expect(
            await coordinator.capture(changedSource) == .rejected(
                AgentSessionRequestRejection(
                    reason: .requestConflict(currentRequest.id),
                    knownCursor: fixture.initialCursor
                )
            )
        )
        #expect(await target.recordedRequests().isEmpty)
        #expect(await target.recordedCurrentRequests().count == 1)
        #expect(await target.requestCount() == 1)

        await target.resumeNextCurrent(with: .coordinatorBusy)
        _ = await acceptedTask.value
        #expect(await target.requestCount() == 1)
    }

    @Test func oversizedCurrentArtifactIsNeverRecapturedAfterEviction() async throws {
        let fixture = try Self.makeFixture()
        let request = fixture.currentRequest(sequence: 0)
        let limits = AgentSessionLimits(
            maximumStepCount: .one,
            maximumRetainedResultCount: 4,
            maximumRetainedImageBytes: 3
        )
        let completed = fixture.currentCompletedOutcome(
            request: request,
            sourceSnapshot: fixture.snapshot(at: fixture.initialCursor),
            encodedBytes: Data([0xFF, 0xD8, 0x66, 0xFF, 0xD9])
        )
        let target = ScriptedCaptureTarget(
            scripts: [.currentImmediate(completed)]
        )
        let coordinator = Self.coordinator(
            fixture: fixture,
            target: target,
            limits: limits
        )

        let response = try Self.executedResponse(
            from: await coordinator.capture(request)
        )
        #expect(response.outcome == .currentCapture(completed))
        #expect(
            await coordinator.capture(request) == .rejected(
                AgentSessionRequestRejection(
                    reason: .resultEvicted(request.id),
                    knownCursor: fixture.initialCursor
                )
            )
        )
        #expect(await target.requestCount() == 1)
    }

    @Test func oversizedCurrentRawFailureAlsoRemainsEvicted() async throws {
        let fixture = try Self.makeFixture()
        let request = fixture.currentRequest(sequence: 0)
        let sourceSnapshot = fixture.snapshot(at: fixture.initialCursor)
        let rawResult = try fixture.rawRenderResult(
            request: request,
            cursor: sourceSnapshot.cursor
        )
        let limits = AgentSessionLimits(
            maximumStepCount: .one,
            maximumRetainedResultCount: 4,
            maximumRetainedImageBytes: 3
        )
        #expect(rawResult.image.bytes.count > limits.maximumRetainedImageBytes)
        let failure = OfflineCurrentCaptureOutcome.jpegEncodingFailed(
            sourceSnapshot: sourceSnapshot,
            renderResult: rawResult,
            failure: .destinationFinalizationFailed
        )
        let target = ScriptedCaptureTarget(
            scripts: [.currentImmediate(failure)]
        )
        let coordinator = Self.coordinator(
            fixture: fixture,
            target: target,
            limits: limits
        )

        let response = try Self.executedResponse(
            from: await coordinator.capture(request)
        )
        #expect(response.outcome == .currentCapture(failure))
        #expect(response.knownCursor == sourceSnapshot.cursor)
        #expect(
            await coordinator.capture(request) == .rejected(
                AgentSessionRequestRejection(
                    reason: .resultEvicted(request.id),
                    knownCursor: sourceSnapshot.cursor
                )
            )
        )
        #expect(await target.requestCount() == 1)
    }

    @Test func currentCursorMismatchRefreshesKnownCursor() async throws {
        let fixture = try Self.makeFixture()
        let request = fixture.currentRequest(sequence: 0)
        let recovered = fixture.initialCursor.advanced()
        let outcome = OfflineCurrentCaptureOutcome.cursorMismatch(
            expected: fixture.initialCursor,
            current: recovered
        )
        let target = ScriptedCaptureTarget(
            scripts: [.currentImmediate(outcome)]
        )
        let coordinator = Self.coordinator(fixture: fixture, target: target)

        let response = try Self.executedResponse(
            from: await coordinator.capture(request)
        )
        #expect(response.outcome == .currentCapture(outcome))
        #expect(response.knownCursor == recovered)
        #expect(await target.requestCount() == 1)
    }

    @Test func completedDuplicateReplaysExactBytesWithoutForwardingAgain() async throws {
        let fixture = try Self.makeFixture()
        let request = fixture.request(sequence: 0)
        let advance = fixture.advanceResult(
            from: fixture.initialCursor,
            by: try Self.advanceStepCount(of: request)
        )
        let expectedBytes = Data([0xFF, 0xD8, 0x10, 0x20, 0x30, 0xFF, 0xD9])
        let completed = fixture.completedOutcome(
            request: request,
            advanceResult: advance,
            encodedBytes: expectedBytes
        )
        let target = ScriptedCaptureTarget(scripts: [.immediate(completed)])
        let coordinator = Self.coordinator(fixture: fixture, target: target)

        let first = try Self.executedResponse(
            from: await coordinator.capture(request)
        )
        let replay = await coordinator.capture(request)

        #expect(replay == .replayed(first))
        #expect(try Self.encodedBytes(in: first) == expectedBytes)
        #expect(await target.requestCount() == 1)
    }

    @Test func changedPayloadConflictsForCachedAndInFlightIdentity() async throws {
        let fixture = try Self.makeFixture()
        let request = fixture.request(sequence: 0)
        let changed = Self.changingStepCount(
            of: request,
            to: SimulationStepCount(rawValue: 2)
        )

        let cachedTarget = ScriptedCaptureTarget(
            scripts: [.immediate(.coordinatorBusy)]
        )
        let cachedCoordinator = Self.coordinator(
            fixture: fixture,
            target: cachedTarget
        )
        _ = try Self.executedResponse(
            from: await cachedCoordinator.capture(request)
        )

        #expect(
            await cachedCoordinator.capture(changed) == .rejected(
                AgentSessionRequestRejection(
                    reason: .requestConflict(request.id),
                    knownCursor: fixture.initialCursor
                )
            )
        )
        #expect(await cachedTarget.requestCount() == 1)

        let inFlightTarget = ScriptedCaptureTarget(scripts: [.suspended])
        let inFlightCoordinator = Self.coordinator(
            fixture: fixture,
            target: inFlightTarget
        )
        let firstTask = Task {
            await inFlightCoordinator.capture(request)
        }
        await inFlightTarget.waitForRequestCount(1)

        #expect(
            await inFlightCoordinator.capture(changed) == .rejected(
                AgentSessionRequestRejection(
                    reason: .requestConflict(request.id),
                    knownCursor: fixture.initialCursor
                )
            )
        )
        #expect(await inFlightTarget.requestCount() == 1)

        await inFlightTarget.resumeNext(with: .coordinatorBusy)
        _ = await firstTask.value
    }

    @Test func suspendedTargetReportsDuplicateInProgressAndNextUniqueBusy() async throws {
        let fixture = try Self.makeFixture()
        let firstRequest = fixture.currentRequest(sequence: 0)
        let nextRequest = fixture.request(sequence: 1)
        let target = ScriptedCaptureTarget(scripts: [.currentSuspended])
        let coordinator = Self.coordinator(fixture: fixture, target: target)
        let firstTask = Task {
            await coordinator.capture(firstRequest)
        }
        await target.waitForRequestCount(1)

        #expect(
            await coordinator.capture(firstRequest) == .requestInProgress(
                requestID: firstRequest.id,
                knownCursor: fixture.initialCursor
            )
        )
        #expect(
            await coordinator.capture(nextRequest) == .rejected(
                AgentSessionRequestRejection(
                    reason: .anotherRequestBusy(
                        activeRequestID: firstRequest.id
                    ),
                    knownCursor: fixture.initialCursor
                )
            )
        )
        #expect(await target.requestCount() == 1)

        await target.resumeNextCurrent(with: .coordinatorBusy)
        _ = await firstTask.value
    }

    @Test func admissionRejectionsDoNotConsumeFirstSequence() async throws {
        let fixture = try Self.makeFixture()
        let target = ScriptedCaptureTarget(
            scripts: [.immediate(.coordinatorBusy)]
        )
        let coordinator = Self.coordinator(fixture: fixture, target: target)
        let first = fixture.request(sequence: 0)

        let otherSession = AgentSessionID()
        let wrongSession = fixture.request(
            sessionID: otherSession,
            sequence: 0
        )
        #expect(
            await coordinator.capture(wrongSession) == .rejected(
                AgentSessionRequestRejection(
                    reason: .wrongSession(
                        expected: fixture.agentSessionID,
                        actual: otherSession
                    ),
                    knownCursor: fixture.initialCursor
                )
            )
        )

        let gap = fixture.request(sequence: 1)
        #expect(
            await coordinator.capture(gap) == .rejected(
                AgentSessionRequestRejection(
                    reason: .unexpectedSequence(
                        expected: .first,
                        actual: gap.id.sequence
                    ),
                    knownCursor: fixture.initialCursor
                )
            )
        )

        let cancelled = await Task {
            withUnsafeCurrentTask { task in
                task?.cancel()
            }
            return await coordinator.capture(first)
        }.value
        #expect(
            cancelled == .rejected(
                AgentSessionRequestRejection(
                    reason: .cancelledBeforeAcceptance,
                    knownCursor: fixture.initialCursor
                )
            )
        )
        #expect(await target.requestCount() == 0)

        _ = try Self.executedResponse(
            from: await coordinator.capture(first)
        )
        #expect(await target.requestCount() == 1)
    }

    @Test func nonreflexivePayloadPreservesIdentityStatusAndFirstSequence() async throws {
        let fixture = try Self.makeFixture()
        let validRequest = fixture.request(sequence: 0)
        let invalidViewpoint = RenderViewpoint(
            id: validRequest.viewpoint.id,
            revision: validRequest.viewpoint.revision,
            camera: Camera(
                position: SIMD3<Float>(.nan, 3, 8)
            )
        )
        let invalidRequest = AgentCaptureRequest(
            id: validRequest.id,
            source: validRequest.source,
            renderRequestID: validRequest.renderRequestID,
            viewpoint: invalidViewpoint,
            renderSettings: validRequest.renderSettings,
            jpegSettings: validRequest.jpegSettings
        )
        let target = ScriptedCaptureTarget(
            scripts: [
                .immediate(.coordinatorBusy),
                .immediate(.coordinatorBusy)
            ]
        )
        let limits = AgentSessionLimits(
            maximumStepCount: SimulationStepCount(rawValue: 4),
            maximumRetainedResultCount: 1,
            maximumRetainedImageBytes: 1_024
        )
        let coordinator = Self.coordinator(
            fixture: fixture,
            target: target,
            limits: limits
        )

        #expect(invalidRequest != invalidRequest)
        #expect(
            await coordinator.capture(invalidRequest) == .rejected(
                AgentSessionRequestRejection(
                    reason: .invalidPayload,
                    knownCursor: fixture.initialCursor
                )
            )
        )
        #expect(await target.requestCount() == 0)

        _ = try Self.executedResponse(
            from: await coordinator.capture(validRequest)
        )
        #expect(await target.requestCount() == 1)

        #expect(
            await coordinator.capture(invalidRequest) == .rejected(
                AgentSessionRequestRejection(
                    reason: .requestConflict(validRequest.id),
                    knownCursor: fixture.initialCursor
                )
            )
        )
        #expect(await target.requestCount() == 1)

        let nextRequest = fixture.request(sequence: 1)
        _ = try Self.executedResponse(
            from: await coordinator.capture(nextRequest)
        )
        #expect(
            await coordinator.capture(invalidRequest) == .rejected(
                AgentSessionRequestRejection(
                    reason: .resultEvicted(validRequest.id),
                    knownCursor: fixture.initialCursor
                )
            )
        )
        #expect(await target.requestCount() == 2)
    }

    @Test func stepLimitTerminalIsCachedAndNextSequenceCanRun() async throws {
        let fixture = try Self.makeFixture()
        let limits = AgentSessionLimits(
            maximumStepCount: SimulationStepCount(rawValue: 2),
            maximumRetainedResultCount: 4,
            maximumRetainedImageBytes: 1_024
        )
        let target = ScriptedCaptureTarget(
            scripts: [.immediate(.coordinatorBusy)]
        )
        let coordinator = Self.coordinator(
            fixture: fixture,
            target: target,
            limits: limits
        )
        let oversizedWork = fixture.request(
            sequence: 0,
            stepCount: SimulationStepCount(rawValue: 3)
        )

        let terminal = try Self.executedResponse(
            from: await coordinator.capture(oversizedWork)
        )
        #expect(
            terminal.outcome == .stepLimitExceeded(
                requested: try Self.advanceStepCount(of: oversizedWork),
                maximum: limits.maximumStepCount
            )
        )
        #expect(terminal.knownCursor == fixture.initialCursor)
        #expect(await target.requestCount() == 0)
        #expect(
            await coordinator.capture(oversizedWork) == .replayed(terminal)
        )
        #expect(await target.requestCount() == 0)

        let next = fixture.request(sequence: 1)
        _ = try Self.executedResponse(from: await coordinator.capture(next))
        #expect(await target.requestCount() == 1)
    }

    @Test func countRetentionEvictsOldestResponseInFIFOOrder() async throws {
        let fixture = try Self.makeFixture()
        let limits = AgentSessionLimits(
            maximumStepCount: SimulationStepCount(rawValue: 4),
            maximumRetainedResultCount: 2,
            maximumRetainedImageBytes: 1_024
        )
        let target = ScriptedCaptureTarget(
            scripts: [
                .immediate(.coordinatorBusy),
                .immediate(.coordinatorBusy),
                .immediate(.coordinatorBusy)
            ]
        )
        let coordinator = Self.coordinator(
            fixture: fixture,
            target: target,
            limits: limits
        )
        let requests = (0...2).map { fixture.request(sequence: UInt64($0)) }
        var responses: [AgentSessionResponse] = []

        for request in requests {
            responses.append(
                try Self.executedResponse(
                    from: await coordinator.capture(request)
                )
            )
        }

        #expect(
            await coordinator.capture(requests[0]) == .rejected(
                AgentSessionRequestRejection(
                    reason: .resultEvicted(requests[0].id),
                    knownCursor: fixture.initialCursor
                )
            )
        )
        #expect(
            await coordinator.capture(requests[1]) == .replayed(responses[1])
        )
        #expect(await target.requestCount() == 3)
    }

    @Test func imageByteBudgetEvictsOldestResponse() async throws {
        let fixture = try Self.makeFixture()
        let limits = AgentSessionLimits(
            maximumStepCount: SimulationStepCount(rawValue: 4),
            maximumRetainedResultCount: 8,
            maximumRetainedImageBytes: 6
        )
        let firstRequest = fixture.request(sequence: 0)
        let firstAdvance = fixture.advanceResult(
            from: fixture.initialCursor,
            by: try Self.advanceStepCount(of: firstRequest)
        )
        let secondRequest = fixture.request(
            sequence: 1,
            expectedCursor: firstAdvance.finalCursor
        )
        let secondAdvance = fixture.advanceResult(
            from: firstAdvance.finalCursor,
            by: try Self.advanceStepCount(of: secondRequest)
        )
        let target = ScriptedCaptureTarget(
            scripts: [
                .immediate(
                    fixture.completedOutcome(
                        request: firstRequest,
                        advanceResult: firstAdvance,
                        encodedBytes: Data([1, 2, 3, 4])
                    )
                ),
                .immediate(
                    fixture.completedOutcome(
                        request: secondRequest,
                        advanceResult: secondAdvance,
                        encodedBytes: Data([5, 6, 7, 8])
                    )
                )
            ]
        )
        let coordinator = Self.coordinator(
            fixture: fixture,
            target: target,
            limits: limits
        )

        _ = try Self.executedResponse(
            from: await coordinator.capture(firstRequest)
        )
        let secondResponse = try Self.executedResponse(
            from: await coordinator.capture(secondRequest)
        )

        #expect(
            await coordinator.capture(firstRequest) == .rejected(
                AgentSessionRequestRejection(
                    reason: .resultEvicted(firstRequest.id),
                    knownCursor: secondAdvance.finalCursor
                )
            )
        )
        #expect(
            await coordinator.capture(secondRequest) == .replayed(secondResponse)
        )
        #expect(await target.requestCount() == 2)
    }

    @Test func oversizeResponseStaysEvictedWithoutRepeatingWork() async throws {
        let fixture = try Self.makeFixture()
        let limits = AgentSessionLimits(
            maximumStepCount: SimulationStepCount(rawValue: 4),
            maximumRetainedResultCount: 8,
            maximumRetainedImageBytes: 3
        )
        let firstRequest = fixture.request(sequence: 0)
        let firstAdvance = fixture.advanceResult(
            from: fixture.initialCursor,
            by: try Self.advanceStepCount(of: firstRequest)
        )
        let nextRequest = fixture.request(
            sequence: 1,
            expectedCursor: firstAdvance.finalCursor
        )
        let target = ScriptedCaptureTarget(
            scripts: [
                .immediate(
                    fixture.completedOutcome(
                        request: firstRequest,
                        advanceResult: firstAdvance,
                        encodedBytes: Data([1, 2, 3, 4])
                    )
                ),
                .immediate(.coordinatorBusy)
            ]
        )
        let coordinator = Self.coordinator(
            fixture: fixture,
            target: target,
            limits: limits
        )

        _ = try Self.executedResponse(
            from: await coordinator.capture(firstRequest)
        )
        let expectedEviction = AgentSessionSubmissionOutcome.rejected(
            AgentSessionRequestRejection(
                reason: .resultEvicted(firstRequest.id),
                knownCursor: firstAdvance.finalCursor
            )
        )
        #expect(await coordinator.capture(firstRequest) == expectedEviction)
        #expect(await coordinator.capture(firstRequest) == expectedEviction)
        #expect(await target.requestCount() == 1)

        _ = try Self.executedResponse(
            from: await coordinator.capture(nextRequest)
        )
        #expect(await coordinator.capture(firstRequest) == expectedEviction)
        #expect(await target.requestCount() == 2)
    }

    @Test func oversizeRawFailureCountsImageBytesAndNeverReforwards() async throws {
        let fixture = try Self.makeFixture()
        let limits = AgentSessionLimits(
            maximumStepCount: SimulationStepCount(rawValue: 4),
            maximumRetainedResultCount: 8,
            maximumRetainedImageBytes: 3
        )
        let request = fixture.request(sequence: 0)
        let advance = fixture.advanceResult(
            from: fixture.initialCursor,
            by: try Self.advanceStepCount(of: request)
        )
        let rawResult = try fixture.rawRenderResult(
            request: request,
            cursor: advance.finalCursor
        )
        #expect(rawResult.image.bytes.count > limits.maximumRetainedImageBytes)

        let target = ScriptedCaptureTarget(
            scripts: [
                .immediate(
                    .jpegEncodingFailed(
                        advanceResult: advance,
                        renderResult: rawResult,
                        failure: .destinationFinalizationFailed
                    )
                )
            ]
        )
        let coordinator = Self.coordinator(
            fixture: fixture,
            target: target,
            limits: limits
        )

        _ = try Self.executedResponse(
            from: await coordinator.capture(request)
        )
        #expect(
            await coordinator.capture(request) == .rejected(
                AgentSessionRequestRejection(
                    reason: .resultEvicted(request.id),
                    knownCursor: advance.finalCursor
                )
            )
        )
        #expect(await target.requestCount() == 1)
    }

    @Test func everyPostAdvanceOutcomeAndCursorMismatchUpdateKnownCursor() async throws {
        let fixture = try Self.makeFixture()
        let request = fixture.request(sequence: 0)
        let requestedStepCount = try Self.advanceStepCount(of: request)
        let advance = fixture.advanceResult(
            from: fixture.initialCursor,
            by: requestedStepCount
        )
        let rawResult = try fixture.rawRenderResult(
            request: request,
            cursor: advance.finalCursor
        )
        let completed = fixture.completedOutcome(
            request: request,
            advanceResult: advance,
            encodedBytes: Data([0xFF, 0xD8, 0xFF, 0xD9])
        )
        let wrongRenderRequestID = OffscreenRenderRequestID()
        let postAdvanceOutcomes: [OfflineCaptureOutcome] = [
            completed,
            .advanceResultMismatch(
                coordinatorCursor: fixture.initialCursor,
                requestedExpectedCursor: request.source.expectedCursor,
                requestedStepCount: requestedStepCount,
                result: advance
            ),
            .cancelledAfterAdvance(advance),
            .renderRejected(
                advanceResult: advance,
                rejection: .runtimeBusy
            ),
            .renderFailed(
                advanceResult: advance,
                failure: OffscreenRenderFailure(
                    stage: .gpuExecution,
                    backendDescription: "scripted"
                )
            ),
            .renderCancellationRequestIDMismatch(
                advanceResult: advance,
                expectedRequestID: request.renderRequestID,
                actualRequestID: wrongRenderRequestID
            ),
            .renderCancelledAfterSubmission(
                advanceResult: advance,
                requestID: request.renderRequestID
            ),
            .renderResultMismatch(
                advanceResult: advance,
                renderResult: rawResult
            ),
            .cancelledAfterRender(
                advanceResult: advance,
                renderResult: rawResult
            ),
            .jpegEncodingFailed(
                advanceResult: advance,
                renderResult: rawResult,
                failure: .destinationFinalizationFailed
            )
        ]

        for outcome in postAdvanceOutcomes {
            let target = ScriptedCaptureTarget(scripts: [.immediate(outcome)])
            let coordinator = Self.coordinator(
                fixture: fixture,
                target: target
            )
            let response = try Self.executedResponse(
                from: await coordinator.capture(request)
            )
            #expect(response.knownCursor == advance.finalCursor)
            #expect(await target.requestCount() == 1)
        }

        let recoveredCursor = SimulationCursor(
            sessionID: fixture.initialCursor.sessionID,
            tick: SimulationTick(rawValue: 99)
        )
        let mismatch = OfflineCaptureOutcome.advanceRejected(
            .cursorMismatch(
                expected: request.source.expectedCursor,
                current: recoveredCursor
            )
        )
        let mismatchTarget = ScriptedCaptureTarget(
            scripts: [.immediate(mismatch)]
        )
        let mismatchCoordinator = Self.coordinator(
            fixture: fixture,
            target: mismatchTarget
        )
        let mismatchResponse = try Self.executedResponse(
            from: await mismatchCoordinator.capture(request)
        )
        #expect(mismatchResponse.knownCursor == recoveredCursor)
        #expect(await mismatchTarget.requestCount() == 1)
    }

    @Test func cancellationAfterAcceptanceIsCachedAndReplayed() async throws {
        let fixture = try Self.makeFixture()
        let request = fixture.request(sequence: 0)
        let advance = fixture.advanceResult(
            from: fixture.initialCursor,
            by: try Self.advanceStepCount(of: request)
        )
        let target = ScriptedCaptureTarget(scripts: [.suspended])
        let coordinator = Self.coordinator(fixture: fixture, target: target)
        let firstTask = Task {
            await coordinator.capture(request)
        }
        await target.waitForRequestCount(1)

        firstTask.cancel()
        await target.resumeNext(with: .cancelledAfterAdvance(advance))
        let firstResponse = try Self.executedResponse(from: await firstTask.value)

        #expect(firstResponse.knownCursor == advance.finalCursor)
        #expect(
            firstResponse.outcome == .capture(.cancelledAfterAdvance(advance))
        )
        #expect(
            await coordinator.capture(request) == .replayed(firstResponse)
        )
        #expect(await target.requestCount() == 1)
    }

    @Test func stopAndDrainClosesImmediatelyAndPreservesReplay() async throws {
        let fixture = try Self.makeFixture()
        let cachedRequest = fixture.request(sequence: 0)
        let activeRequest = fixture.request(sequence: 1)
        let newRequest = fixture.request(sequence: 2)
        let target = ScriptedCaptureTarget(
            scripts: [
                .immediate(.coordinatorBusy),
                .suspended
            ]
        )
        let coordinator = Self.coordinator(fixture: fixture, target: target)

        let cachedResponse = try Self.executedResponse(
            from: await coordinator.capture(cachedRequest)
        )
        let activeTask = Task {
            await coordinator.capture(activeRequest)
        }
        await target.waitForRequestCount(2)

        let drainCompletion = CompletionFlag()
        let drainTask = Task {
            await coordinator.stopAndDrain()
            await drainCompletion.markComplete()
        }

        let closedRejection = await Self.waitForClosedRejection(
            from: coordinator,
            request: newRequest,
            activeRequestID: activeRequest.id
        )
        #expect(
            closedRejection == AgentSessionRequestRejection(
                reason: .sessionClosed,
                knownCursor: fixture.initialCursor
            )
        )
        let drainedBeforeResume = await drainCompletion.isComplete()
        #expect(!drainedBeforeResume)
        #expect(
            await coordinator.capture(cachedRequest) == .replayed(cachedResponse)
        )

        await target.resumeNext(with: .coordinatorBusy)
        let activeResponse = try Self.executedResponse(from: await activeTask.value)
        await drainTask.value
        #expect(await drainCompletion.isComplete())
        #expect(
            await coordinator.capture(activeRequest) == .replayed(activeResponse)
        )
        #expect(
            await coordinator.capture(newRequest) == .rejected(
                AgentSessionRequestRejection(
                    reason: .sessionClosed,
                    knownCursor: fixture.initialCursor
                )
            )
        )
        #expect(await target.requestCount() == 2)
    }

    @Test func concurrentDrainCallersBothWaitForAcceptedWork() async throws {
        let fixture = try Self.makeFixture()
        let activeRequest = fixture.request(sequence: 0)
        let newRequest = fixture.request(sequence: 1)
        let target = ScriptedCaptureTarget(scripts: [.suspended])
        let coordinator = Self.coordinator(fixture: fixture, target: target)
        let activeTask = Task {
            await coordinator.capture(activeRequest)
        }
        await target.waitForRequestCount(1)

        let startGate = StartGate(requiredArrivalCount: 2)
        let completions = CompletionCounter()
        let firstDrain = Task {
            await startGate.arriveAndWait()
            await coordinator.stopAndDrain()
            await completions.increment()
        }
        let secondDrain = Task {
            await startGate.arriveAndWait()
            await coordinator.stopAndDrain()
            await completions.increment()
        }
        await startGate.waitUntilAllArrived()
        await startGate.releaseAll()

        _ = await Self.waitForClosedRejection(
            from: coordinator,
            request: newRequest,
            activeRequestID: activeRequest.id
        )
        #expect(await completions.value() == 0)

        await target.resumeNext(with: .coordinatorBusy)
        _ = await activeTask.value
        await firstDrain.value
        await secondDrain.value
        #expect(await completions.value() == 2)
        #expect(await target.requestCount() == 1)
    }

    @Test func maximumSequenceUnretainedRetryRemainsEvicted() async throws {
        let fixture = try Self.makeFixture()
        let maximum = AgentSessionRequestSequence(rawValue: .max)
        #expect(maximum.successor() == nil)

        let maximumRequest = fixture.request(sequence: .max)
        let maximumAdvance = fixture.advanceResult(
            from: fixture.initialCursor,
            by: try Self.advanceStepCount(of: maximumRequest)
        )
        let limits = AgentSessionLimits(
            maximumStepCount: SimulationStepCount(rawValue: 4),
            maximumRetainedResultCount: 4,
            maximumRetainedImageBytes: 0
        )
        let target = ScriptedCaptureTarget(
            scripts: [
                .immediate(
                    fixture.completedOutcome(
                        request: maximumRequest,
                        advanceResult: maximumAdvance,
                        encodedBytes: Data([0xFF, 0xD8, 0xFF, 0xD9])
                    )
                )
            ]
        )
        let coordinator = Self.coordinator(
            fixture: fixture,
            target: target,
            limits: limits,
            initialRequestSequence: maximum
        )
        _ = try Self.executedResponse(
            from: await coordinator.capture(maximumRequest)
        )

        #expect(
            await coordinator.capture(maximumRequest) == .rejected(
                AgentSessionRequestRejection(
                    reason: .resultEvicted(maximumRequest.id),
                    knownCursor: maximumAdvance.finalCursor
                )
            )
        )
        #expect(await target.requestCount() == 1)
    }

    private static func coordinator(
        fixture: Fixture,
        target: ScriptedCaptureTarget,
        limits: AgentSessionLimits = .conservativeDefault,
        initialRequestSequence: AgentSessionRequestSequence = .first
    ) -> AgentSessionCoordinator {
        AgentSessionCoordinator(
            sessionID: fixture.agentSessionID,
            initialCursor: fixture.initialCursor,
            limits: limits,
            captureTarget: target,
            initialRequestSequence: initialRequestSequence
        )
    }

    private static func changingStepCount(
        of request: AgentCaptureRequest,
        to stepCount: SimulationStepCount
    ) -> AgentCaptureRequest {
        AgentCaptureRequest(
            id: request.id,
            expectedCursor: request.source.expectedCursor,
            stepCount: stepCount,
            renderRequestID: request.renderRequestID,
            viewpoint: request.viewpoint,
            renderSettings: request.renderSettings,
            jpegSettings: request.jpegSettings
        )
    }

    private static func advanceStepCount(
        of request: AgentCaptureRequest
    ) throws -> SimulationStepCount {
        guard case let .advance(_, stepCount) = request.source else {
            Issue.record("Expected an advancing agent request.")
            throw UnexpectedOutcome()
        }
        return stepCount
    }

    private static func executedResponse(
        from outcome: AgentSessionSubmissionOutcome
    ) throws -> AgentSessionResponse {
        guard case let .executed(response) = outcome else {
            Issue.record("Expected executed agent response, received \(outcome)")
            throw UnexpectedOutcome()
        }
        return response
    }

    private static func encodedBytes(
        in response: AgentSessionResponse
    ) throws -> Data {
        guard case let .capture(.completed(result)) = response.outcome else {
            Issue.record("Expected completed artifact response.")
            throw UnexpectedOutcome()
        }
        return result.artifact.encodedData
    }

    private static func waitForClosedRejection(
        from coordinator: AgentSessionCoordinator,
        request: AgentCaptureRequest,
        activeRequestID: AgentSessionRequestID
    ) async -> AgentSessionRequestRejection {
        while true {
            let outcome = await coordinator.capture(request)
            guard case let .rejected(rejection) = outcome else {
                Issue.record("Expected a non-consuming rejection while draining.")
                return AgentSessionRequestRejection(
                    reason: .sessionClosed,
                    knownCursor: request.source.expectedCursor
                )
            }

            switch rejection.reason {
            case .sessionClosed:
                return rejection

            case let .anotherRequestBusy(activeID):
                #expect(activeID == activeRequestID)
                await Task.yield()

            default:
                Issue.record(
                    "Unexpected rejection while waiting for close: \(rejection)"
                )
                return rejection
            }
        }
    }

    private static func rawRoundTrip<Value>(
        _ value: Value
    ) -> Value? where Value: Equatable & RawRepresentable {
        Value(rawValue: value.rawValue)
    }

    private static func makeFixture() throws -> Fixture {
        let simulationSessionID = SimulationSessionID(
            rawValue: UUID(
                uuidString: "50000000-0000-0000-0000-000000000001"
            )!
        )
        let agentSessionID = AgentSessionID(
            rawValue: UUID(
                uuidString: "50000000-0000-0000-0000-000000000002"
            )!
        )
        let initialCursor = SimulationCursor(
            sessionID: simulationSessionID,
            tick: SimulationTick(rawValue: 10)
        )
        let viewpoint = RenderViewpoint(
            id: RenderViewpointID(
                rawValue: UUID(
                    uuidString: "50000000-0000-0000-0000-000000000003"
                )!
            ),
            revision: RenderViewpointRevision(rawValue: 4),
            camera: Camera(position: SIMD3<Float>(2, 3, 8))
        )
        let renderSettings = OffscreenRenderSettings(
            size: try RenderPixelSize(width: 2, height: 2),
            outputMode: .surface,
            exposure: .validation
        )
        let jpegSettings = JPEGEncodingSettings(
            quality: try JPEGQuality(0.8)
        )

        return Fixture(
            agentSessionID: agentSessionID,
            initialCursor: initialCursor,
            viewpoint: viewpoint,
            renderSettings: renderSettings,
            jpegSettings: jpegSettings
        )
    }

    private struct Fixture: Sendable {
        let agentSessionID: AgentSessionID
        let initialCursor: SimulationCursor
        let viewpoint: RenderViewpoint
        let renderSettings: OffscreenRenderSettings
        let jpegSettings: JPEGEncodingSettings

        func request(
            sessionID: AgentSessionID? = nil,
            sequence: UInt64,
            expectedCursor: SimulationCursor? = nil,
            stepCount: SimulationStepCount = .one
        ) -> AgentCaptureRequest {
            AgentCaptureRequest(
                id: AgentSessionRequestID(
                    sessionID: sessionID ?? agentSessionID,
                    sequence: AgentSessionRequestSequence(rawValue: sequence)
                ),
                expectedCursor: expectedCursor ?? initialCursor,
                stepCount: stepCount,
                renderRequestID: OffscreenRenderRequestID(),
                viewpoint: viewpoint,
                renderSettings: renderSettings,
                jpegSettings: jpegSettings
            )
        }

        func currentRequest(
            sessionID: AgentSessionID? = nil,
            sequence: UInt64,
            expectedCursor: SimulationCursor? = nil,
            viewpoint: RenderViewpoint? = nil
        ) -> AgentCaptureRequest {
            AgentCaptureRequest.current(
                id: AgentSessionRequestID(
                    sessionID: sessionID ?? agentSessionID,
                    sequence: AgentSessionRequestSequence(rawValue: sequence)
                ),
                expectedCursor: expectedCursor ?? initialCursor,
                renderRequestID: OffscreenRenderRequestID(),
                viewpoint: viewpoint ?? self.viewpoint,
                renderSettings: renderSettings,
                jpegSettings: jpegSettings
            )
        }

        func snapshot(at cursor: SimulationCursor) -> SimulationPresentationSnapshot {
            SimulationPresentationSnapshot(
                cursor: cursor,
                camera: viewpoint.camera,
                entityPresentations: []
            )
        }

        func advanceResult(
            from initialCursor: SimulationCursor,
            by stepCount: SimulationStepCount
        ) -> SimulationAdvanceResult {
            var finalTick = initialCursor.tick
            for _ in 0..<stepCount.rawValue {
                finalTick = finalTick.advanced()
            }
            let finalCursor = SimulationCursor(
                sessionID: initialCursor.sessionID,
                tick: finalTick
            )
            let snapshot = SimulationPresentationSnapshot(
                cursor: finalCursor,
                camera: viewpoint.camera,
                entityPresentations: []
            )
            return SimulationAdvanceResult(
                initialCursor: initialCursor,
                finalCursor: finalCursor,
                completedStepCount: SimulationCompletedStepCount(
                    rawValue: stepCount.rawValue
                ),
                finalPresentationSnapshot: snapshot
            )
        }

        func completedOutcome(
            request: AgentCaptureRequest,
            advanceResult: SimulationAdvanceResult,
            encodedBytes: Data
        ) -> OfflineCaptureOutcome {
            let artifact = RenderedImageArtifact(
                format: .jpeg,
                encodedData: encodedBytes,
                sourceRequestID: request.renderRequestID,
                sourceCursor: advanceResult.finalCursor,
                viewpoint: request.viewpoint,
                renderSettings: request.renderSettings,
                jpegSettings: request.jpegSettings
            )
            return .completed(
                OfflineCaptureResult(
                    advanceResult: advanceResult,
                    artifact: artifact
                )
            )
        }

        func currentCompletedOutcome(
            request: AgentCaptureRequest,
            sourceSnapshot: SimulationPresentationSnapshot,
            encodedBytes: Data
        ) -> OfflineCurrentCaptureOutcome {
            let artifact = RenderedImageArtifact(
                format: .jpeg,
                encodedData: encodedBytes,
                sourceRequestID: request.renderRequestID,
                sourceCursor: sourceSnapshot.cursor,
                viewpoint: request.viewpoint,
                renderSettings: request.renderSettings,
                jpegSettings: request.jpegSettings
            )
            return .completed(
                OfflineCurrentCaptureResult(
                    sourceSnapshot: sourceSnapshot,
                    artifact: artifact
                )
            )
        }

        func rawRenderResult(
            request: AgentCaptureRequest,
            cursor: SimulationCursor
        ) throws -> OffscreenRenderResult {
            let bytes = Data(
                repeating: 0x7F,
                count: request.renderSettings.size.pixelCount * 4
            )
            return OffscreenRenderResult(
                requestID: request.renderRequestID,
                sourceCursor: cursor,
                viewpoint: request.viewpoint,
                settings: request.renderSettings,
                image: try RenderedBGRA8SRGBImage(
                    size: request.renderSettings.size,
                    bytes: bytes
                )
            )
        }
    }

    private actor ScriptedCaptureTarget: POfflineCaptureTarget {
        enum Script: Sendable {
            case immediate(OfflineCaptureOutcome)
            case suspended
            case currentImmediate(OfflineCurrentCaptureOutcome)
            case currentSuspended
        }

        private struct CountWaiter {
            let count: Int
            let continuation: CheckedContinuation<Void, Never>
        }

        private var scripts: [Script]
        private var requests: [OfflineCaptureRequest] = []
        private var currentRequests: [OfflineCurrentCaptureRequest] = []
        private var suspended: [
            CheckedContinuation<OfflineCaptureOutcome, Never>
        ] = []
        private var suspendedCurrent: [
            CheckedContinuation<OfflineCurrentCaptureOutcome, Never>
        ] = []
        private var countWaiters: [CountWaiter] = []

        init(scripts: [Script]) {
            self.scripts = scripts
        }

        func capture(
            _ request: OfflineCaptureRequest
        ) async -> OfflineCaptureOutcome {
            requests.append(request)
            notifyCountWaiters()

            guard !scripts.isEmpty else {
                Issue.record("Agent session forwarded more work than scripted.")
                return .coordinatorBusy
            }

            switch scripts.removeFirst() {
            case let .immediate(outcome):
                return outcome

            case .suspended:
                return await withCheckedContinuation { continuation in
                    suspended.append(continuation)
                }

            case .currentImmediate, .currentSuspended:
                Issue.record("Agent session selected the wrong offline operation.")
                return .coordinatorBusy
            }
        }

        func captureCurrent(
            _ request: OfflineCurrentCaptureRequest
        ) async -> OfflineCurrentCaptureOutcome {
            currentRequests.append(request)
            notifyCountWaiters()

            guard !scripts.isEmpty else {
                Issue.record("Agent session forwarded more work than scripted.")
                return .coordinatorBusy
            }

            switch scripts.removeFirst() {
            case let .currentImmediate(outcome):
                return outcome

            case .currentSuspended:
                return await withCheckedContinuation { continuation in
                    suspendedCurrent.append(continuation)
                }

            case .immediate, .suspended:
                Issue.record("Agent session selected the wrong offline operation.")
                return .coordinatorBusy
            }
        }

        func requestCount() -> Int {
            requests.count + currentRequests.count
        }

        func recordedRequests() -> [OfflineCaptureRequest] {
            requests
        }

        func recordedCurrentRequests() -> [OfflineCurrentCaptureRequest] {
            currentRequests
        }

        func waitForRequestCount(_ count: Int) async {
            guard totalRequestCount < count else {
                return
            }
            await withCheckedContinuation { continuation in
                countWaiters.append(
                    CountWaiter(count: count, continuation: continuation)
                )
            }
        }

        func resumeNext(with outcome: OfflineCaptureOutcome) {
            guard !suspended.isEmpty else {
                Issue.record("No scripted agent capture was suspended.")
                return
            }
            suspended.removeFirst().resume(returning: outcome)
        }

        func resumeNextCurrent(with outcome: OfflineCurrentCaptureOutcome) {
            guard !suspendedCurrent.isEmpty else {
                Issue.record("No scripted current capture was suspended.")
                return
            }
            suspendedCurrent.removeFirst().resume(returning: outcome)
        }

        private var totalRequestCount: Int {
            requests.count + currentRequests.count
        }

        private func notifyCountWaiters() {
            var remaining: [CountWaiter] = []
            for waiter in countWaiters {
                if totalRequestCount >= waiter.count {
                    waiter.continuation.resume()
                } else {
                    remaining.append(waiter)
                }
            }
            countWaiters = remaining
        }
    }

    private actor CompletionFlag {
        private var complete = false

        func markComplete() {
            complete = true
        }

        func isComplete() -> Bool {
            complete
        }
    }

    private actor CompletionCounter {
        private var count = 0

        func increment() {
            count += 1
        }

        func value() -> Int {
            count
        }
    }

    private actor StartGate {
        private let requiredArrivalCount: Int
        private var arrivalCount = 0
        private var arrivalWaiters: [CheckedContinuation<Void, Never>] = []
        private var releaseWaiters: [CheckedContinuation<Void, Never>] = []
        private var isReleased = false

        init(requiredArrivalCount: Int) {
            self.requiredArrivalCount = requiredArrivalCount
        }

        func arriveAndWait() async {
            arrivalCount += 1
            if arrivalCount >= requiredArrivalCount {
                let waiters = arrivalWaiters
                arrivalWaiters.removeAll()
                for waiter in waiters {
                    waiter.resume()
                }
            }

            guard !isReleased else {
                return
            }
            await withCheckedContinuation { continuation in
                releaseWaiters.append(continuation)
            }
        }

        func waitUntilAllArrived() async {
            guard arrivalCount < requiredArrivalCount else {
                return
            }
            await withCheckedContinuation { continuation in
                arrivalWaiters.append(continuation)
            }
        }

        func releaseAll() {
            isReleased = true
            let waiters = releaseWaiters
            releaseWaiters.removeAll()
            for waiter in waiters {
                waiter.resume()
            }
        }
    }

    private struct UnexpectedOutcome: Error {}
}
