import Foundation
import simd
import Testing
@testable import Engine2

struct AgentSessionCoordinatorTests {
    @Test func sessionIdentitySupportsFreshRawAndCodableRoundTrips() throws {
        let parsedRawValue = UUID(
            uuidString: "50000000-0000-0000-0000-000000000000"
        )
        let rawValue = try #require(parsedRawValue)
        let fixed = AgentSessionID(rawValue: rawValue)
        let firstFresh = AgentSessionID()
        let secondFresh = AgentSessionID()

        #expect(firstFresh != secondFresh)
        #expect(rawRoundTrip(fixed) == fixed)

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
            #expect(rawRoundTrip(sequence) == sequence)
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
        let fixture = try makeFixture()
        let request = fixture.request(sequence: 0)
        let target = ScriptedCaptureTarget(
            scripts: [.immediate(.cancelledBeforeAdvance)]
        )
        let coordinator = coordinator(fixture: fixture, target: target)

        let response = try executedResponse(
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
        #expect(forwarded.encoding == request.encoding)
    }

    @Test func currentCommandMapsExactRequestWithoutAdvancing() async throws {
        let fixture = try makeFixture()
        let request = fixture.currentRequest(sequence: 0)
        let sourceSnapshot = fixture.snapshot(at: fixture.initialCursor)
        let encodedBytes = Data([0xFF, 0xD8, 0x44, 0xFF, 0xD9])
        let completed = fixture.currentCompletedOutcome(
            request: request,
            sourceSnapshot: sourceSnapshot,
            encodedBytes: encodedBytes
        )
        let target = ScriptedCaptureTarget(
            scripts: [.currentImmediate(completed)]
        )
        let coordinator = coordinator(fixture: fixture, target: target)

        let response = try executedResponse(
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
        #expect(forwarded.encoding == request.encoding)
        #expect(await target.requestCount() == 1)
    }

    @Test func currentReplayAndChangedSourceShareOneIdentityLane() async throws {
        let fixture = try makeFixture()
        let request = fixture.currentRequest(sequence: 0)
        let encodedBytes = Data([0xFF, 0xD8, 0x55, 0xFF, 0xD9])
        let completed = fixture.currentCompletedOutcome(
            request: request,
            sourceSnapshot: fixture.snapshot(at: fixture.initialCursor),
            encodedBytes: encodedBytes
        )
        let target = ScriptedCaptureTarget(
            scripts: [.currentImmediate(completed)]
        )
        let coordinator = coordinator(fixture: fixture, target: target)

        let first = try executedResponse(
            from: await coordinator.capture(request)
        )
        #expect(await coordinator.capture(request) == .replayed(first))

        let changedSource = AgentCaptureRequest(
            id: request.id,
            source: .advance(
                expectedCursor: fixture.initialCursor,
                stepCount: .one
            ),
            renderRequestID: request.renderRequestID,
            viewpoint: request.viewpoint,
            renderSettings: request.renderSettings,
            encoding: request.encoding
        )
        let rejection = AgentSessionRequestRejection(
            reason: .requestConflict(request.id),
            knownCursor: fixture.initialCursor
        )
        #expect(
            await coordinator.capture(changedSource) == .rejected(rejection)
        )
        #expect(await target.requestCount() == 1)
    }

    @Test func inFlightCurrentConflictsWithAdvanceAtTheSameIdentity() async throws {
        let fixture = try makeFixture()
        let currentRequest = fixture.currentRequest(sequence: 0)
        let changedSource = AgentCaptureRequest(
            id: currentRequest.id,
            source: .advance(
                expectedCursor: currentRequest.source.expectedCursor,
                stepCount: .one
            ),
            renderRequestID: currentRequest.renderRequestID,
            viewpoint: currentRequest.viewpoint,
            renderSettings: currentRequest.renderSettings,
            encoding: currentRequest.encoding
        )
        let target = ScriptedCaptureTarget(scripts: [.currentSuspended])
        let coordinator = coordinator(fixture: fixture, target: target)
        let acceptedTask = Task {
            await coordinator.capture(currentRequest)
        }
        await target.waitForRequestCount(1)

        let rejection = AgentSessionRequestRejection(
            reason: .requestConflict(currentRequest.id),
            knownCursor: fixture.initialCursor
        )
        #expect(
            await coordinator.capture(changedSource) == .rejected(rejection)
        )
        #expect(await target.recordedRequests().isEmpty)
        #expect(await target.recordedCurrentRequests().count == 1)
        #expect(await target.requestCount() == 1)

        await target.resumeNextCurrent(with: .coordinatorBusy)
        _ = await acceptedTask.value
        #expect(await target.requestCount() == 1)
    }

    @Test func oversizedCurrentArtifactIsNeverRecapturedAfterEviction() async throws {
        let fixture = try makeFixture()
        let request = fixture.currentRequest(sequence: 0)
        let limits = AgentSessionLimits(
            maximumStepCount: .one,
            maximumRetainedResultCount: 4,
            maximumRetainedImageBytes: 3
        )
        let encodedBytes = Data([0xFF, 0xD8, 0x66, 0xFF, 0xD9])
        let completed = fixture.currentCompletedOutcome(
            request: request,
            sourceSnapshot: fixture.snapshot(at: fixture.initialCursor),
            encodedBytes: encodedBytes
        )
        let target = ScriptedCaptureTarget(
            scripts: [.currentImmediate(completed)]
        )
        let coordinator = coordinator(
            fixture: fixture,
            target: target,
            limits: limits
        )

        let response = try executedResponse(
            from: await coordinator.capture(request)
        )
        #expect(response.outcome == .currentCapture(completed))
        let rejection = AgentSessionRequestRejection(
            reason: .resultEvicted(request.id),
            knownCursor: fixture.initialCursor
        )
        #expect(
            await coordinator.capture(request) == .rejected(rejection)
        )
        #expect(await target.requestCount() == 1)
    }

    @Test func oversizedCurrentRawFailureAlsoRemainsEvicted() async throws {
        let fixture = try makeFixture()
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
        let failure = OfflineCurrentCaptureOutcome.artifactEncodingFailed(
            sourceSnapshot: sourceSnapshot,
            renderResult: rawResult,
            failure: .destinationFinalizationFailed
        )
        let target = ScriptedCaptureTarget(
            scripts: [.currentImmediate(failure)]
        )
        let coordinator = coordinator(
            fixture: fixture,
            target: target,
            limits: limits
        )

        let response = try executedResponse(
            from: await coordinator.capture(request)
        )
        #expect(response.outcome == .currentCapture(failure))
        #expect(response.knownCursor == sourceSnapshot.cursor)
        let rejection = AgentSessionRequestRejection(
            reason: .resultEvicted(request.id),
            knownCursor: sourceSnapshot.cursor
        )
        #expect(
            await coordinator.capture(request) == .rejected(rejection)
        )
        #expect(await target.requestCount() == 1)
    }

    @Test func currentCursorMismatchRefreshesKnownCursor() async throws {
        let fixture = try makeFixture()
        let request = fixture.currentRequest(sequence: 0)
        let recovered = fixture.initialCursor.advanced()
        let outcome = OfflineCurrentCaptureOutcome.cursorMismatch(
            expected: fixture.initialCursor,
            current: recovered
        )
        let target = ScriptedCaptureTarget(
            scripts: [.currentImmediate(outcome)]
        )
        let coordinator = coordinator(fixture: fixture, target: target)

        let response = try executedResponse(
            from: await coordinator.capture(request)
        )
        #expect(response.outcome == .currentCapture(outcome))
        #expect(response.knownCursor == recovered)
        #expect(await target.requestCount() == 1)
    }

    @Test func currentArtifactMismatchRefreshesCursorAndCountsBothPayloads() async throws {
        let fixture = try makeFixture()
        let request = fixture.currentRequest(sequence: 0)
        let sourceSnapshot = fixture.snapshot(at: fixture.initialCursor)
        let rawResult = try fixture.rawRenderResult(
            request: request,
            cursor: sourceSnapshot.cursor
        )
        let encodedBytes = Data(repeating: 0x50, count: 8)
        let artifact = fixture.artifact(
            request: request,
            cursor: sourceSnapshot.cursor,
            encodedBytes: encodedBytes,
            encoding: .png
        )
        #expect(rawResult.image.bytes.count == 16)
        #expect(artifact.encodedData.count == 8)
        let outcome = OfflineCurrentCaptureOutcome.artifactResultMismatch(
            sourceSnapshot: sourceSnapshot,
            renderResult: rawResult,
            artifact: artifact
        )
        let target = ScriptedCaptureTarget(
            scripts: [.currentImmediate(outcome)]
        )
        let limits = AgentSessionLimits(
            maximumStepCount: .one,
            maximumRetainedResultCount: 4,
            maximumRetainedImageBytes: 23
        )
        let coordinator = coordinator(
            fixture: fixture,
            target: target,
            limits: limits
        )

        let response = try executedResponse(
            from: await coordinator.capture(request)
        )
        #expect(response.knownCursor == sourceSnapshot.cursor)
        #expect(response.outcome == .currentCapture(outcome))
        let rejection = AgentSessionRequestRejection(
            reason: .resultEvicted(request.id),
            knownCursor: sourceSnapshot.cursor
        )
        #expect(
            await coordinator.capture(request) == .rejected(rejection)
        )
        #expect(await target.requestCount() == 1)
    }

    @Test func completedDuplicateReplaysExactBytesWithoutForwardingAgain() async throws {
        let fixture = try makeFixture()
        let request = fixture.request(sequence: 0)
        let advance = fixture.advanceResult(
            from: fixture.initialCursor,
            by: try advanceStepCount(of: request)
        )
        let expectedBytes = Data([0xFF, 0xD8, 0x10, 0x20, 0x30, 0xFF, 0xD9])
        let completed = fixture.completedOutcome(
            request: request,
            advanceResult: advance,
            encodedBytes: expectedBytes
        )
        let target = ScriptedCaptureTarget(scripts: [.immediate(completed)])
        let coordinator = coordinator(fixture: fixture, target: target)

        let first = try executedResponse(
            from: await coordinator.capture(request)
        )
        let replay = await coordinator.capture(request)

        #expect(replay == .replayed(first))
        #expect(try encodedBytes(in: first) == expectedBytes)
        #expect(await target.requestCount() == 1)
    }

    @Test func changedPayloadConflictsForCachedAndInFlightIdentity() async throws {
        let fixture = try makeFixture()
        let request = fixture.request(sequence: 0)
        let changedStepCount = SimulationStepCount(rawValue: 2)
        let changed = changingStepCount(
            of: request,
            to: changedStepCount
        )
        let changedEncoding = changingEncoding(
            of: request,
            to: .png
        )

        let cachedTarget = ScriptedCaptureTarget(
            scripts: [.immediate(.coordinatorBusy)]
        )
        let cachedCoordinator = coordinator(
            fixture: fixture,
            target: cachedTarget
        )
        _ = try executedResponse(
            from: await cachedCoordinator.capture(request)
        )

        let cachedRejection = AgentSessionRequestRejection(
            reason: .requestConflict(request.id),
            knownCursor: fixture.initialCursor
        )
        #expect(
            await cachedCoordinator.capture(changed)
                == .rejected(cachedRejection)
        )
        #expect(
            await cachedCoordinator.capture(changedEncoding)
                == .rejected(cachedRejection)
        )
        #expect(await cachedTarget.requestCount() == 1)

        let inFlightTarget = ScriptedCaptureTarget(scripts: [.suspended])
        let inFlightCoordinator = coordinator(
            fixture: fixture,
            target: inFlightTarget
        )
        let firstTask = Task {
            await inFlightCoordinator.capture(request)
        }
        await inFlightTarget.waitForRequestCount(1)

        let inFlightRejection = AgentSessionRequestRejection(
            reason: .requestConflict(request.id),
            knownCursor: fixture.initialCursor
        )
        #expect(
            await inFlightCoordinator.capture(changed)
                == .rejected(inFlightRejection)
        )
        #expect(
            await inFlightCoordinator.capture(changedEncoding)
                == .rejected(inFlightRejection)
        )
        #expect(await inFlightTarget.requestCount() == 1)

        await inFlightTarget.resumeNext(with: .coordinatorBusy)
        _ = await firstTask.value
    }

    @Test func suspendedTargetReportsDuplicateInProgressAndNextUniqueBusy() async throws {
        let fixture = try makeFixture()
        let firstRequest = fixture.currentRequest(sequence: 0)
        let nextRequest = fixture.request(sequence: 1)
        let target = ScriptedCaptureTarget(scripts: [.currentSuspended])
        let coordinator = coordinator(fixture: fixture, target: target)
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
        let busyRejection = AgentSessionRequestRejection(
            reason: .anotherRequestBusy(activeRequestID: firstRequest.id),
            knownCursor: fixture.initialCursor
        )
        #expect(
            await coordinator.capture(nextRequest) == .rejected(busyRejection)
        )
        #expect(await target.requestCount() == 1)

        await target.resumeNextCurrent(with: .coordinatorBusy)
        _ = await firstTask.value
    }

    @Test func admissionRejectionsDoNotConsumeFirstSequence() async throws {
        let fixture = try makeFixture()
        let target = ScriptedCaptureTarget(
            scripts: [.immediate(.coordinatorBusy)]
        )
        let coordinator = coordinator(fixture: fixture, target: target)
        let first = fixture.request(sequence: 0)

        let otherSession = AgentSessionID()
        let wrongSession = fixture.request(
            sessionID: otherSession,
            sequence: 0
        )
        let wrongSessionRejection = AgentSessionRequestRejection(
            reason: .wrongSession(
                expected: fixture.agentSessionID,
                actual: otherSession
            ),
            knownCursor: fixture.initialCursor
        )
        #expect(
            await coordinator.capture(wrongSession)
                == .rejected(wrongSessionRejection)
        )

        let gap = fixture.request(sequence: 1)
        let sequenceRejection = AgentSessionRequestRejection(
            reason: .unexpectedSequence(
                expected: .first,
                actual: gap.id.sequence
            ),
            knownCursor: fixture.initialCursor
        )
        #expect(
            await coordinator.capture(gap) == .rejected(sequenceRejection)
        )

        let cancelled = await Task {
            withUnsafeCurrentTask { task in
                task?.cancel()
            }
            return await coordinator.capture(first)
        }.value
        let cancellationRejection = AgentSessionRequestRejection(
            reason: .cancelledBeforeAcceptance,
            knownCursor: fixture.initialCursor
        )
        #expect(
            cancelled == .rejected(cancellationRejection)
        )
        #expect(await target.requestCount() == 0)

        _ = try executedResponse(
            from: await coordinator.capture(first)
        )
        #expect(await target.requestCount() == 1)
    }

    @Test func nonreflexivePayloadPreservesIdentityStatusAndFirstSequence() async throws {
        let fixture = try makeFixture()
        let validRequest = fixture.request(sequence: 0)
        let invalidCameraPosition = SIMD3<Float>(.nan, 3, 8)
        let invalidCamera = Camera(
            position: invalidCameraPosition,
            rotation: Transform.identityRotation,
            projection: .standardPerspective
        )
        let invalidViewpoint = RenderViewpoint(
            id: validRequest.viewpoint.id,
            revision: validRequest.viewpoint.revision,
            camera: invalidCamera
        )
        let invalidRequest = AgentCaptureRequest(
            id: validRequest.id,
            source: validRequest.source,
            renderRequestID: validRequest.renderRequestID,
            viewpoint: invalidViewpoint,
            renderSettings: validRequest.renderSettings,
            encoding: validRequest.encoding
        )
        let target = ScriptedCaptureTarget(
            scripts: [
                .immediate(.coordinatorBusy),
                .immediate(.coordinatorBusy)
            ]
        )
        let maximumStepCount = SimulationStepCount(rawValue: 4)
        let limits = AgentSessionLimits(
            maximumStepCount: maximumStepCount,
            maximumRetainedResultCount: 1,
            maximumRetainedImageBytes: 1_024
        )
        let coordinator = coordinator(
            fixture: fixture,
            target: target,
            limits: limits
        )

        #expect(invalidRequest != invalidRequest)
        let invalidPayloadRejection = AgentSessionRequestRejection(
            reason: .invalidPayload,
            knownCursor: fixture.initialCursor
        )
        #expect(
            await coordinator.capture(invalidRequest)
                == .rejected(invalidPayloadRejection)
        )
        #expect(await target.requestCount() == 0)

        _ = try executedResponse(
            from: await coordinator.capture(validRequest)
        )
        #expect(await target.requestCount() == 1)

        let conflictRejection = AgentSessionRequestRejection(
            reason: .requestConflict(validRequest.id),
            knownCursor: fixture.initialCursor
        )
        #expect(
            await coordinator.capture(invalidRequest)
                == .rejected(conflictRejection)
        )
        #expect(await target.requestCount() == 1)

        let nextRequest = fixture.request(sequence: 1)
        _ = try executedResponse(
            from: await coordinator.capture(nextRequest)
        )
        let evictedRejection = AgentSessionRequestRejection(
            reason: .resultEvicted(validRequest.id),
            knownCursor: fixture.initialCursor
        )
        #expect(
            await coordinator.capture(invalidRequest)
                == .rejected(evictedRejection)
        )
        #expect(await target.requestCount() == 2)
    }

    @Test func stepLimitTerminalIsCachedAndNextSequenceCanRun() async throws {
        let fixture = try makeFixture()
        let maximumStepCount = SimulationStepCount(rawValue: 2)
        let limits = AgentSessionLimits(
            maximumStepCount: maximumStepCount,
            maximumRetainedResultCount: 4,
            maximumRetainedImageBytes: 1_024
        )
        let target = ScriptedCaptureTarget(
            scripts: [.immediate(.coordinatorBusy)]
        )
        let coordinator = coordinator(
            fixture: fixture,
            target: target,
            limits: limits
        )
        let requestedStepCount = SimulationStepCount(rawValue: 3)
        let oversizedWork = fixture.request(
            sequence: 0,
            stepCount: requestedStepCount
        )

        let terminal = try executedResponse(
            from: await coordinator.capture(oversizedWork)
        )
        #expect(
            terminal.outcome == .stepLimitExceeded(
                requested: try advanceStepCount(of: oversizedWork),
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
        _ = try executedResponse(from: await coordinator.capture(next))
        #expect(await target.requestCount() == 1)
    }

    @Test func replayCacheKeepsRequestAndResponsePairedThroughFIFOEviction() throws {
        let fixture = try makeFixture()
        var cache = AgentSessionReplayCache(
            maximumResultCount: 2,
            maximumImageBytes: 1_024
        )
        let entries = (0...2).map { sequence in
            let requestSequence = UInt64(sequence)
            let request = fixture.request(sequence: requestSequence)
            let requestedStepCount = SimulationStepCount(rawValue: 2)
            let response = AgentSessionResponse(
                requestID: request.id,
                outcome: .stepLimitExceeded(
                    requested: requestedStepCount,
                    maximum: .one
                ),
                knownCursor: fixture.initialCursor
            )
            return AgentSessionReplayEntry(
                request: request,
                response: response
            )
        }

        cache.retain(entries[0])
        cache.retain(entries[1])

        #expect(cache.entry(for: entries[0].requestID) == entries[0])
        #expect(cache.entry(for: entries[1].requestID) == entries[1])

        cache.retain(entries[2])

        #expect(cache.entry(for: entries[0].requestID) == nil)
        #expect(cache.entry(for: entries[1].requestID) == entries[1])
        #expect(cache.entry(for: entries[2].requestID) == entries[2])
    }

    @Test func replayCacheImageBudgetEvictsFIFOAndLeavesOversizedEntriesUnretained() throws {
        let fixture = try makeFixture()
        var cache = AgentSessionReplayCache(
            maximumResultCount: 4,
            maximumImageBytes: 6
        )
        let requests = (0...2).map {
            let requestSequence = UInt64($0)
            return fixture.currentRequest(sequence: requestSequence)
        }
        let entries = requests.enumerated().map { index, request in
            let byteCount = index == 2 ? 7 : 4
            let byte = UInt8(index)
            let encodedBytes = Data(repeating: byte, count: byteCount)
            let outcome = fixture.currentCompletedOutcome(
                request: request,
                sourceSnapshot: fixture.snapshot(at: fixture.initialCursor),
                encodedBytes: encodedBytes
            )
            let response = AgentSessionResponse(
                requestID: request.id,
                outcome: .currentCapture(outcome),
                knownCursor: fixture.initialCursor
            )
            return AgentSessionReplayEntry(
                request: request,
                response: response
            )
        }
        #expect(entries.map(\.retainedImageByteCount) == [4, 4, 7])

        cache.retain(entries[0])
        cache.retain(entries[1])

        #expect(cache.entry(for: entries[0].requestID) == nil)
        #expect(cache.entry(for: entries[1].requestID) == entries[1])

        cache.retain(entries[2])

        #expect(cache.entry(for: entries[1].requestID) == entries[1])
        #expect(cache.entry(for: entries[2].requestID) == nil)
    }

    @Test func replayCacheCountsRawAndEncodedMismatchPayloadsTogether() throws {
        let fixture = try makeFixture()
        let request = fixture.request(sequence: 0)
        let advance = fixture.advanceResult(
            from: fixture.initialCursor,
            by: try advanceStepCount(of: request)
        )
        let rawResult = try fixture.rawRenderResult(
            request: request,
            cursor: advance.finalCursor
        )
        let encodedBytes = Data(repeating: 0x50, count: 8)
        let artifact = fixture.artifact(
            request: request,
            cursor: advance.finalCursor,
            encodedBytes: encodedBytes,
            encoding: .png
        )
        #expect(rawResult.image.bytes.count == 16)
        #expect(artifact.encodedData.count == 8)

        let response = AgentSessionResponse(
            requestID: request.id,
            outcome: .capture(
                .artifactResultMismatch(
                    advanceResult: advance,
                    renderResult: rawResult,
                    artifact: artifact
                )
            ),
            knownCursor: advance.finalCursor
        )
        var cache = AgentSessionReplayCache(
            maximumResultCount: 4,
            maximumImageBytes: 23
        )
        let entry = AgentSessionReplayEntry(
            request: request,
            response: response
        )
        #expect(entry.retainedImageByteCount == 24)

        cache.retain(entry)

        #expect(cache.entry(for: request.id) == nil)
    }

    @Test func countRetentionEvictsOldestResponseInFIFOOrder() async throws {
        let fixture = try makeFixture()
        let maximumStepCount = SimulationStepCount(rawValue: 4)
        let limits = AgentSessionLimits(
            maximumStepCount: maximumStepCount,
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
        let coordinator = coordinator(
            fixture: fixture,
            target: target,
            limits: limits
        )
        let requests = (0...2).map {
            let requestSequence = UInt64($0)
            return fixture.request(sequence: requestSequence)
        }
        var responses: [AgentSessionResponse] = []

        for request in requests {
            responses.append(
                try executedResponse(
                    from: await coordinator.capture(request)
                )
            )
        }

        let rejection = AgentSessionRequestRejection(
            reason: .resultEvicted(requests[0].id),
            knownCursor: fixture.initialCursor
        )
        #expect(
            await coordinator.capture(requests[0]) == .rejected(rejection)
        )
        #expect(
            await coordinator.capture(requests[1]) == .replayed(responses[1])
        )
        #expect(await target.requestCount() == 3)
    }

    @Test func imageByteBudgetEvictsOldestResponse() async throws {
        let fixture = try makeFixture()
        let maximumStepCount = SimulationStepCount(rawValue: 4)
        let limits = AgentSessionLimits(
            maximumStepCount: maximumStepCount,
            maximumRetainedResultCount: 8,
            maximumRetainedImageBytes: 6
        )
        let firstRequest = fixture.request(sequence: 0)
        let firstAdvance = fixture.advanceResult(
            from: fixture.initialCursor,
            by: try advanceStepCount(of: firstRequest)
        )
        let secondRequest = fixture.request(
            sequence: 1,
            expectedCursor: firstAdvance.finalCursor
        )
        let secondAdvance = fixture.advanceResult(
            from: firstAdvance.finalCursor,
            by: try advanceStepCount(of: secondRequest)
        )
        let firstBytes = Data([1, 2, 3, 4])
        let firstOutcome = fixture.completedOutcome(
            request: firstRequest,
            advanceResult: firstAdvance,
            encodedBytes: firstBytes
        )
        let secondBytes = Data([5, 6, 7, 8])
        let secondOutcome = fixture.completedOutcome(
            request: secondRequest,
            advanceResult: secondAdvance,
            encodedBytes: secondBytes
        )
        let target = ScriptedCaptureTarget(
            scripts: [
                .immediate(firstOutcome),
                .immediate(secondOutcome)
            ]
        )
        let coordinator = coordinator(
            fixture: fixture,
            target: target,
            limits: limits
        )

        _ = try executedResponse(
            from: await coordinator.capture(firstRequest)
        )
        let secondResponse = try executedResponse(
            from: await coordinator.capture(secondRequest)
        )

        let rejection = AgentSessionRequestRejection(
            reason: .resultEvicted(firstRequest.id),
            knownCursor: secondAdvance.finalCursor
        )
        #expect(
            await coordinator.capture(firstRequest) == .rejected(rejection)
        )
        #expect(
            await coordinator.capture(secondRequest) == .replayed(secondResponse)
        )
        #expect(await target.requestCount() == 2)
    }

    @Test func oversizeResponseStaysEvictedWithoutRepeatingWork() async throws {
        let fixture = try makeFixture()
        let maximumStepCount = SimulationStepCount(rawValue: 4)
        let limits = AgentSessionLimits(
            maximumStepCount: maximumStepCount,
            maximumRetainedResultCount: 8,
            maximumRetainedImageBytes: 3
        )
        let firstRequest = fixture.request(sequence: 0)
        let firstAdvance = fixture.advanceResult(
            from: fixture.initialCursor,
            by: try advanceStepCount(of: firstRequest)
        )
        let nextRequest = fixture.request(
            sequence: 1,
            expectedCursor: firstAdvance.finalCursor
        )
        let encodedBytes = Data([1, 2, 3, 4])
        let completed = fixture.completedOutcome(
            request: firstRequest,
            advanceResult: firstAdvance,
            encodedBytes: encodedBytes
        )
        let target = ScriptedCaptureTarget(
            scripts: [
                .immediate(completed),
                .immediate(.coordinatorBusy)
            ]
        )
        let coordinator = coordinator(
            fixture: fixture,
            target: target,
            limits: limits
        )

        _ = try executedResponse(
            from: await coordinator.capture(firstRequest)
        )
        let rejection = AgentSessionRequestRejection(
            reason: .resultEvicted(firstRequest.id),
            knownCursor: firstAdvance.finalCursor
        )
        let expectedEviction = AgentSessionSubmissionOutcome.rejected(rejection)
        #expect(await coordinator.capture(firstRequest) == expectedEviction)
        #expect(await coordinator.capture(firstRequest) == expectedEviction)
        #expect(await target.requestCount() == 1)

        _ = try executedResponse(
            from: await coordinator.capture(nextRequest)
        )
        #expect(await coordinator.capture(firstRequest) == expectedEviction)
        #expect(await target.requestCount() == 2)
    }

    @Test func oversizeRawFailureCountsImageBytesAndNeverReforwards() async throws {
        let fixture = try makeFixture()
        let maximumStepCount = SimulationStepCount(rawValue: 4)
        let limits = AgentSessionLimits(
            maximumStepCount: maximumStepCount,
            maximumRetainedResultCount: 8,
            maximumRetainedImageBytes: 3
        )
        let request = fixture.request(sequence: 0)
        let advance = fixture.advanceResult(
            from: fixture.initialCursor,
            by: try advanceStepCount(of: request)
        )
        let rawResult = try fixture.rawRenderResult(
            request: request,
            cursor: advance.finalCursor
        )
        #expect(rawResult.image.bytes.count > limits.maximumRetainedImageBytes)

        let target = ScriptedCaptureTarget(
            scripts: [
                .immediate(
                    .artifactEncodingFailed(
                        advanceResult: advance,
                        renderResult: rawResult,
                        failure: .destinationFinalizationFailed
                    )
                )
            ]
        )
        let coordinator = coordinator(
            fixture: fixture,
            target: target,
            limits: limits
        )

        _ = try executedResponse(
            from: await coordinator.capture(request)
        )
        let rejection = AgentSessionRequestRejection(
            reason: .resultEvicted(request.id),
            knownCursor: advance.finalCursor
        )
        #expect(
            await coordinator.capture(request) == .rejected(rejection)
        )
        #expect(await target.requestCount() == 1)
    }

    @Test func artifactMismatchBudgetCountsRawAndEncodedPayloads() async throws {
        let fixture = try makeFixture()
        let request = fixture.request(sequence: 0)
        let advance = fixture.advanceResult(
            from: fixture.initialCursor,
            by: try advanceStepCount(of: request)
        )
        let rawResult = try fixture.rawRenderResult(
            request: request,
            cursor: advance.finalCursor
        )
        let encodedBytes = Data(repeating: 0x50, count: 8)
        let artifact = fixture.artifact(
            request: request,
            cursor: advance.finalCursor,
            encodedBytes: encodedBytes,
            encoding: .png
        )
        #expect(rawResult.image.bytes.count == 16)
        #expect(artifact.encodedData.count == 8)
        let mismatch = OfflineCaptureOutcome.artifactResultMismatch(
            advanceResult: advance,
            renderResult: rawResult,
            artifact: artifact
        )
        let target = ScriptedCaptureTarget(
            scripts: [.immediate(mismatch)]
        )
        let maximumStepCount = SimulationStepCount(rawValue: 4)
        let limits = AgentSessionLimits(
            maximumStepCount: maximumStepCount,
            maximumRetainedResultCount: 4,
            maximumRetainedImageBytes: 23
        )
        let coordinator = coordinator(
            fixture: fixture,
            target: target,
            limits: limits
        )

        let response = try executedResponse(
            from: await coordinator.capture(request)
        )
        #expect(response.knownCursor == advance.finalCursor)
        #expect(response.outcome == .capture(mismatch))
        let rejection = AgentSessionRequestRejection(
            reason: .resultEvicted(request.id),
            knownCursor: advance.finalCursor
        )
        #expect(
            await coordinator.capture(request) == .rejected(rejection)
        )
        #expect(await target.requestCount() == 1)
    }

    @Test func everyPostAdvanceOutcomeAndCursorMismatchUpdateKnownCursor() async throws {
        let fixture = try makeFixture()
        let request = fixture.request(sequence: 0)
        let requestedStepCount = try advanceStepCount(of: request)
        let advance = fixture.advanceResult(
            from: fixture.initialCursor,
            by: requestedStepCount
        )
        let rawResult = try fixture.rawRenderResult(
            request: request,
            cursor: advance.finalCursor
        )
        let completedBytes = Data([0xFF, 0xD8, 0xFF, 0xD9])
        let completed = fixture.completedOutcome(
            request: request,
            advanceResult: advance,
            encodedBytes: completedBytes
        )
        let mismatchedBytes = Data([0x89, 0x50, 0x4E, 0x47])
        let mismatchedArtifact = fixture.artifact(
            request: request,
            cursor: advance.finalCursor,
            encodedBytes: mismatchedBytes,
            encoding: .png
        )
        let wrongRenderRequestID = OffscreenRenderRequestID()
        let renderFailure = OffscreenRenderFailure(
            stage: .gpuExecution,
            backendDescription: "scripted"
        )
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
                failure: renderFailure
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
            .artifactEncodingFailed(
                advanceResult: advance,
                renderResult: rawResult,
                failure: .destinationFinalizationFailed
            ),
            .artifactResultMismatch(
                advanceResult: advance,
                renderResult: rawResult,
                artifact: mismatchedArtifact
            )
        ]

        for outcome in postAdvanceOutcomes {
            let target = ScriptedCaptureTarget(scripts: [.immediate(outcome)])
            let coordinator = coordinator(
                fixture: fixture,
                target: target
            )
            let response = try executedResponse(
                from: await coordinator.capture(request)
            )
            #expect(response.knownCursor == advance.finalCursor)
            #expect(await target.requestCount() == 1)
        }

        let recoveredTick = SimulationTick(rawValue: 99)
        let recoveredCursor = SimulationCursor(
            sessionID: fixture.initialCursor.sessionID,
            tick: recoveredTick
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
        let mismatchCoordinator = coordinator(
            fixture: fixture,
            target: mismatchTarget
        )
        let mismatchResponse = try executedResponse(
            from: await mismatchCoordinator.capture(request)
        )
        #expect(mismatchResponse.knownCursor == recoveredCursor)
        #expect(await mismatchTarget.requestCount() == 1)
    }

    @Test func cancellationAfterAcceptanceIsCachedAndReplayed() async throws {
        let fixture = try makeFixture()
        let request = fixture.request(sequence: 0)
        let advance = fixture.advanceResult(
            from: fixture.initialCursor,
            by: try advanceStepCount(of: request)
        )
        let target = ScriptedCaptureTarget(scripts: [.suspended])
        let coordinator = coordinator(fixture: fixture, target: target)
        let firstTask = Task {
            await coordinator.capture(request)
        }
        await target.waitForRequestCount(1)

        firstTask.cancel()
        await target.resumeNext(with: .cancelledAfterAdvance(advance))
        let firstResponse = try executedResponse(from: await firstTask.value)

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
        let fixture = try makeFixture()
        let cachedRequest = fixture.request(sequence: 0)
        let activeRequest = fixture.request(sequence: 1)
        let newRequest = fixture.request(sequence: 2)
        let target = ScriptedCaptureTarget(
            scripts: [
                .immediate(.coordinatorBusy),
                .suspended
            ]
        )
        let coordinator = coordinator(fixture: fixture, target: target)

        let cachedResponse = try executedResponse(
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

        let closedRejection = await waitForClosedRejection(
            from: coordinator,
            request: newRequest,
            activeRequestID: activeRequest.id
        )
        let expectedClosedRejection = AgentSessionRequestRejection(
            reason: .sessionClosed,
            knownCursor: fixture.initialCursor
        )
        #expect(closedRejection == expectedClosedRejection)
        let drainedBeforeResume = await drainCompletion.isComplete()
        #expect(!drainedBeforeResume)
        #expect(
            await coordinator.capture(cachedRequest) == .replayed(cachedResponse)
        )

        await target.resumeNext(with: .coordinatorBusy)
        let activeResponse = try executedResponse(from: await activeTask.value)
        await drainTask.value
        #expect(await drainCompletion.isComplete())
        #expect(
            await coordinator.capture(activeRequest) == .replayed(activeResponse)
        )
        let closedSubmissionRejection = AgentSessionRequestRejection(
            reason: .sessionClosed,
            knownCursor: fixture.initialCursor
        )
        #expect(
            await coordinator.capture(newRequest)
                == .rejected(closedSubmissionRejection)
        )
        #expect(await target.requestCount() == 2)
    }

    @Test func concurrentDrainCallersBothWaitForAcceptedWork() async throws {
        let fixture = try makeFixture()
        let activeRequest = fixture.request(sequence: 0)
        let newRequest = fixture.request(sequence: 1)
        let target = ScriptedCaptureTarget(scripts: [.suspended])
        let coordinator = coordinator(fixture: fixture, target: target)
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

        _ = await waitForClosedRejection(
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
        let fixture = try makeFixture()
        let maximum = AgentSessionRequestSequence(rawValue: .max)
        #expect(maximum.successor() == nil)

        let maximumRequest = fixture.request(sequence: .max)
        let maximumAdvance = fixture.advanceResult(
            from: fixture.initialCursor,
            by: try advanceStepCount(of: maximumRequest)
        )
        let maximumStepCount = SimulationStepCount(rawValue: 4)
        let limits = AgentSessionLimits(
            maximumStepCount: maximumStepCount,
            maximumRetainedResultCount: 4,
            maximumRetainedImageBytes: 0
        )
        let encodedBytes = Data([0xFF, 0xD8, 0xFF, 0xD9])
        let completed = fixture.completedOutcome(
            request: maximumRequest,
            advanceResult: maximumAdvance,
            encodedBytes: encodedBytes
        )
        let target = ScriptedCaptureTarget(
            scripts: [
                .immediate(completed)
            ]
        )
        let coordinator = coordinator(
            fixture: fixture,
            target: target,
            limits: limits,
            initialRequestSequence: maximum
        )
        _ = try executedResponse(
            from: await coordinator.capture(maximumRequest)
        )

        let rejection = AgentSessionRequestRejection(
            reason: .resultEvicted(maximumRequest.id),
            knownCursor: maximumAdvance.finalCursor
        )
        #expect(
            await coordinator.capture(maximumRequest) == .rejected(rejection)
        )
        #expect(await target.requestCount() == 1)
    }

    private func coordinator(
        fixture: Fixture,
        target: ScriptedCaptureTarget,
        limits: AgentSessionLimits = .conservative,
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

    private func changingStepCount(
        of request: AgentCaptureRequest,
        to stepCount: SimulationStepCount
    ) -> AgentCaptureRequest {
        AgentCaptureRequest(
            id: request.id,
            source: .advance(
                expectedCursor: request.source.expectedCursor,
                stepCount: stepCount
            ),
            renderRequestID: request.renderRequestID,
            viewpoint: request.viewpoint,
            renderSettings: request.renderSettings,
            encoding: request.encoding
        )
    }

    private func changingEncoding(
        of request: AgentCaptureRequest,
        to encoding: ImageArtifactEncoding
    ) -> AgentCaptureRequest {
        AgentCaptureRequest(
            id: request.id,
            source: request.source,
            renderRequestID: request.renderRequestID,
            viewpoint: request.viewpoint,
            renderSettings: request.renderSettings,
            encoding: encoding
        )
    }

    private func advanceStepCount(of request: AgentCaptureRequest) throws -> SimulationStepCount {
        guard case let .advance(_, stepCount) = request.source else {
            Issue.record("Expected an advancing agent request.")
            throw UnexpectedOutcome()
        }
        return stepCount
    }

    private func executedResponse(from outcome: AgentSessionSubmissionOutcome) throws -> AgentSessionResponse {
        guard case let .executed(response) = outcome else {
            Issue.record("Expected executed agent response, received \(outcome)")
            throw UnexpectedOutcome()
        }
        return response
    }

    private func encodedBytes(in response: AgentSessionResponse) throws -> Data {
        guard case let .capture(.completed(result)) = response.outcome else {
            Issue.record("Expected completed artifact response.")
            throw UnexpectedOutcome()
        }
        return result.artifact.encodedData
    }

    private func waitForClosedRejection(
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
                Issue.record("Unexpected rejection while waiting for close: \(rejection)")
                return rejection
            }
        }
    }

    private func rawRoundTrip<Value>(_ value: Value) -> Value? where Value: Equatable & RawRepresentable {
        Value(rawValue: value.rawValue)
    }

    private func makeFixture() throws -> Fixture {
        let simulationSessionUUID = UUID(
            uuidString: "50000000-0000-0000-0000-000000000001"
        )!
        let simulationSessionID = SimulationSessionID(
            rawValue: simulationSessionUUID
        )
        let agentSessionUUID = UUID(
            uuidString: "50000000-0000-0000-0000-000000000002"
        )!
        let agentSessionID = AgentSessionID(
            rawValue: agentSessionUUID
        )
        let initialTick = SimulationTick(rawValue: 10)
        let initialCursor = SimulationCursor(
            sessionID: simulationSessionID,
            tick: initialTick
        )
        let viewpointUUID = UUID(
            uuidString: "50000000-0000-0000-0000-000000000003"
        )!
        let viewpointID = RenderViewpointID(rawValue: viewpointUUID)
        let viewpointRevision = RenderViewpointRevision(rawValue: 4)
        let camera = Camera(
            position: SIMD3<Float>(2, 3, 8),
            rotation: Transform.identityRotation,
            projection: .standardPerspective
        )
        let viewpoint = RenderViewpoint(
            id: viewpointID,
            revision: viewpointRevision,
            camera: camera
        )
        let renderSize = try RenderPixelSize(width: 2, height: 2)
        let renderSettings = OffscreenRenderSettings(
            size: renderSize,
            outputMode: .surface,
            exposure: .validation
        )
        let jpegQuality = try JPEGQuality(0.8)
        let encoding = ImageArtifactEncoding.jpeg(quality: jpegQuality)

        return Fixture(
            agentSessionID: agentSessionID,
            initialCursor: initialCursor,
            viewpoint: viewpoint,
            renderSettings: renderSettings,
            encoding: encoding
        )
    }

    private struct Fixture: Sendable {
        let agentSessionID: AgentSessionID
        let initialCursor: SimulationCursor
        let viewpoint: RenderViewpoint
        let renderSettings: OffscreenRenderSettings
        let encoding: ImageArtifactEncoding

        func request(
            sessionID: AgentSessionID? = nil,
            sequence: UInt64,
            expectedCursor: SimulationCursor? = nil,
            stepCount: SimulationStepCount = .one
        ) -> AgentCaptureRequest {
            let requestSequence = AgentSessionRequestSequence(rawValue: sequence)
            let requestID = AgentSessionRequestID(
                sessionID: sessionID ?? agentSessionID,
                sequence: requestSequence
            )
            let renderRequestID = OffscreenRenderRequestID()
            return AgentCaptureRequest(
                id: requestID,
                source: .advance(
                    expectedCursor: expectedCursor ?? initialCursor,
                    stepCount: stepCount
                ),
                renderRequestID: renderRequestID,
                viewpoint: viewpoint,
                renderSettings: renderSettings,
                encoding: encoding
            )
        }

        func currentRequest(
            sessionID: AgentSessionID? = nil,
            sequence: UInt64,
            expectedCursor: SimulationCursor? = nil,
            viewpoint: RenderViewpoint? = nil
        ) -> AgentCaptureRequest {
            let requestSequence = AgentSessionRequestSequence(rawValue: sequence)
            let requestID = AgentSessionRequestID(
                sessionID: sessionID ?? agentSessionID,
                sequence: requestSequence
            )
            let renderRequestID = OffscreenRenderRequestID()
            return AgentCaptureRequest(
                id: requestID,
                source: .current(expectedCursor: expectedCursor ?? initialCursor),
                renderRequestID: renderRequestID,
                viewpoint: viewpoint ?? self.viewpoint,
                renderSettings: renderSettings,
                encoding: encoding
            )
        }

        func snapshot(at cursor: SimulationCursor) -> SimulationPresentationSnapshot {
            SimulationPresentationSnapshot(
                cursor: cursor,
                camera: viewpoint.camera,
                entityPresentations: []
            )
        }

        func advanceResult(from initialCursor: SimulationCursor, by stepCount: SimulationStepCount) -> SimulationAdvanceResult {
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
            let completedStepCount = SimulationCompletedStepCount(
                rawValue: stepCount.rawValue
            )
            return SimulationAdvanceResult(
                initialCursor: initialCursor,
                finalCursor: finalCursor,
                completedStepCount: completedStepCount,
                finalPresentationSnapshot: snapshot
            )
        }

        func completedOutcome(
            request: AgentCaptureRequest,
            advanceResult: SimulationAdvanceResult,
            encodedBytes: Data
        ) -> OfflineCaptureOutcome {
            let artifact = artifact(
                request: request,
                cursor: advanceResult.finalCursor,
                encodedBytes: encodedBytes
            )
            let result = OfflineCaptureResult(
                advanceResult: advanceResult,
                artifact: artifact
            )
            return .completed(result)
        }

        func currentCompletedOutcome(
            request: AgentCaptureRequest,
            sourceSnapshot: SimulationPresentationSnapshot,
            encodedBytes: Data
        ) -> OfflineCurrentCaptureOutcome {
            let artifact = artifact(
                request: request,
                cursor: sourceSnapshot.cursor,
                encodedBytes: encodedBytes
            )
            let result = OfflineCurrentCaptureResult(
                sourceSnapshot: sourceSnapshot,
                artifact: artifact
            )
            return .completed(result)
        }

        func artifact(
            request: AgentCaptureRequest,
            cursor: SimulationCursor,
            encodedBytes: Data,
            encoding: ImageArtifactEncoding? = nil
        ) -> RenderedImageArtifact {
            RenderedImageArtifact(
                encoding: encoding ?? request.encoding,
                encodedData: encodedBytes,
                sourceRequestID: request.renderRequestID,
                sourceCursor: cursor,
                viewpoint: request.viewpoint,
                renderSettings: request.renderSettings
            )
        }

        func rawRenderResult(request: AgentCaptureRequest, cursor: SimulationCursor) throws -> OffscreenRenderResult {
            let bytes = Data(
                repeating: 0x7F,
                count: request.renderSettings.size.bgra8ByteCount
            )
            let image = try RenderedBGRA8SRGBImage(
                size: request.renderSettings.size,
                bytes: bytes
            )
            return OffscreenRenderResult(
                requestID: request.renderRequestID,
                sourceCursor: cursor,
                viewpoint: request.viewpoint,
                settings: request.renderSettings,
                image: image
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

        func capture(_ request: OfflineCaptureRequest) async -> OfflineCaptureOutcome {
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

        func captureCurrent(_ request: OfflineCurrentCaptureRequest) async -> OfflineCurrentCaptureOutcome {
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
                let waiter = CountWaiter(
                    count: count,
                    continuation: continuation
                )
                countWaiters.append(waiter)
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
