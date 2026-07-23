/// Live-process idempotency and lifecycle owner for one agent capture session.
///
/// The coordinator receives only ``POfflineCaptureTarget``. It never acquires a
/// second Simulation advance path or reproduces advance/render/encode staging.
/// Advancing and current-state captures share one identity, admission, replay,
/// retention, overlap, and drain lane; only advancing work observes step limits.
/// Accepted request high-water is independent of bounded response retention, so
/// eviction can make an old result unavailable but can never make it executable.
actor AgentSessionCoordinator: PAgentSessionTarget {
    let sessionID: AgentSessionID
    let limits: AgentSessionLimits

    private let captureTarget: any POfflineCaptureTarget
    private var knownCursor: SimulationCursor
    private var nextExpectedSequence: AgentSessionRequestSequence?
    private var highestAcceptedSequence: AgentSessionRequestSequence? = nil
    private var activeRequest: AgentCaptureRequest?
    private var isClosed = false

    private var retainedRequests: [AgentSessionRequestID: AgentCaptureRequest] = [:]
    private var retainedResponses: [AgentSessionRequestID: AgentSessionResponse] = [:]
    private var retentionOrder: [AgentSessionRequestID] = []
    private var retainedImageBytes = 0
    private var drainWaiters: [CheckedContinuation<Void, Never>] = []

    /// Creates one session around the already composed offline workflow.
    init(
        sessionID: AgentSessionID,
        initialCursor: SimulationCursor,
        limits: AgentSessionLimits,
        captureTarget: any POfflineCaptureTarget,
        initialRequestSequence: AgentSessionRequestSequence = .first
    ) {
        self.sessionID = sessionID
        self.knownCursor = initialCursor
        self.limits = limits
        self.captureTarget = captureTarget
        self.nextExpectedSequence = initialRequestSequence
    }

    /// Admits, executes once, replays, or refuses one stable request value.
    func capture(
        _ request: AgentCaptureRequest
    ) async -> AgentSessionSubmissionOutcome {
        guard request.id.sessionID == sessionID else {
            return rejected(
                .wrongSession(
                    expected: sessionID,
                    actual: request.id.sessionID
                )
            )
        }

        // Retained replay and payload conflict take precedence even after close.
        if let retainedRequest = retainedRequests[request.id],
           let retainedResponse = retainedResponses[request.id] {
            guard retainedRequest == request else {
                return rejected(.requestConflict(request.id))
            }
            return .replayed(retainedResponse)
        }

        // Actor reentrancy makes the accepted call visible while it awaits the
        // lower-level workflow. A duplicate never joins or executes twice.
        if let activeRequest, activeRequest.id == request.id {
            guard activeRequest == request else {
                return rejected(.requestConflict(request.id))
            }
            return .requestInProgress(
                requestID: request.id,
                knownCursor: knownCursor
            )
        }

        // Accepted high-water survives both cache eviction and UInt64 sequence
        // exhaustion. An old unretained identity therefore remains explicitly
        // evicted rather than becoming executable or losing its diagnosis.
        if let highestAcceptedSequence,
           request.id.sequence <= highestAcceptedSequence {
            return rejected(.resultEvicted(request.id))
        }

        guard !isClosed else {
            return rejected(.sessionClosed)
        }

        if let activeRequest {
            return rejected(
                .anotherRequestBusy(activeRequestID: activeRequest.id)
            )
        }

        guard let nextExpectedSequence else {
            // Accepting UInt64.max preserves it as highestAcceptedSequence, so
            // every representable identity is caught as old above. Keep this
            // defensive fallback non-executing if internal state is corrupted.
            return rejected(.resultEvicted(request.id))
        }
        guard request.id.sequence == nextExpectedSequence else {
            return rejected(
                .unexpectedSequence(
                    expected: nextExpectedSequence,
                    actual: request.id.sequence
                )
            )
        }

        // Idempotency depends on a stable equivalence relation. Swift floating-
        // point NaN is not equal to itself, and Camera currently permits callers
        // to construct such a value. Identity history and lifecycle precedence
        // have already been resolved above; refuse a new non-reflexive payload
        // before it consumes this otherwise-admissible sequence.
        guard request == request else {
            return rejected(.invalidPayload)
        }
        guard !Task.isCancelled else {
            return rejected(.cancelledBeforeAcceptance)
        }

        // From this point the request identity is consumed exactly once. Move
        // high-water before the first await so overlap can never admit it again.
        activeRequest = request
        highestAcceptedSequence = nextExpectedSequence
        self.nextExpectedSequence = nextExpectedSequence.successor()

        let response: AgentSessionResponse
        switch request.source {
        case let .advance(expectedCursor, stepCount):
            if stepCount.rawValue > limits.maximumStepCount.rawValue {
                response = AgentSessionResponse(
                    requestID: request.id,
                    outcome: .stepLimitExceeded(
                        requested: stepCount,
                        maximum: limits.maximumStepCount
                    ),
                    knownCursor: knownCursor
                )
            } else {
                let outcome = await captureTarget.capture(
                    request.makeOfflineCaptureRequest(
                        expectedCursor: expectedCursor,
                        stepCount: stepCount
                    )
                )
                knownCursor = Self.knownCursor(
                    after: outcome,
                    previous: knownCursor
                )
                response = AgentSessionResponse(
                    requestID: request.id,
                    outcome: .capture(outcome),
                    knownCursor: knownCursor
                )
            }

        case let .current(expectedCursor):
            let outcome = await captureTarget.captureCurrent(
                request.makeOfflineCurrentCaptureRequest(
                    expectedCursor: expectedCursor
                )
            )
            knownCursor = Self.knownCursor(
                after: outcome,
                previous: knownCursor
            )
            response = AgentSessionResponse(
                requestID: request.id,
                outcome: .currentCapture(outcome),
                knownCursor: knownCursor
            )
        }

        retain(response: response, for: request)
        activeRequest = nil
        resumeDrainWaiters()
        return .executed(response)
    }

    /// Closes admission immediately and waits for already accepted work.
    ///
    /// Retained identical requests remain replayable while this coordinator is
    /// alive. Closing never cancels or rolls back the lower-level exact workflow.
    func stopAndDrain() async {
        isClosed = true
        guard activeRequest != nil else {
            return
        }

        await withCheckedContinuation { continuation in
            drainWaiters.append(continuation)
        }
    }

    /// Forms a non-consuming rejection at the currently known cursor.
    private func rejected(
        _ reason: AgentSessionRequestRejectionReason
    ) -> AgentSessionSubmissionOutcome {
        .rejected(
            AgentSessionRequestRejection(
                reason: reason,
                knownCursor: knownCursor
            )
        )
    }

    /// Retains a response within both count and named image-byte budgets.
    private func retain(
        response: AgentSessionResponse,
        for request: AgentCaptureRequest
    ) {
        let imageBytes = Self.retainedImageByteCount(in: response.outcome)
        guard imageBytes <= limits.maximumRetainedImageBytes else {
            return
        }

        while retentionOrder.count >= limits.maximumRetainedResultCount
            || retainedImageBytes
                > limits.maximumRetainedImageBytes - imageBytes {
            guard let oldestID = retentionOrder.first else {
                return
            }
            retentionOrder.removeFirst()
            retainedRequests[oldestID] = nil
            if let evictedResponse = retainedResponses.removeValue(
                forKey: oldestID
            ) {
                retainedImageBytes -= Self.retainedImageByteCount(
                    in: evictedResponse.outcome
                )
            }
        }

        retainedRequests[request.id] = request
        retainedResponses[request.id] = response
        retentionOrder.append(request.id)
        retainedImageBytes += imageBytes
    }

    /// Resumes every closer only after accepted work reaches a terminal value.
    private func resumeDrainWaiters() {
        let waiters = drainWaiters
        drainWaiters.removeAll()
        for waiter in waiters {
            waiter.resume()
        }
    }

    /// Derives the exact authoritative position exposed with an agent response.
    private static func knownCursor(
        after outcome: OfflineCaptureOutcome,
        previous: SimulationCursor
    ) -> SimulationCursor {
        switch outcome {
        case let .completed(result):
            result.advanceResult.finalCursor

        case .coordinatorBusy,
             .cancelledBeforeAdvance:
            previous

        case let .advanceRejected(rejection):
            switch rejection {
            case let .cursorMismatch(_, current):
                current
            }

        case let .advanceResultMismatch(_, _, _, result),
             let .cancelledAfterAdvance(result),
             let .renderRejected(result, _),
             let .renderFailed(result, _),
             let .renderCancellationRequestIDMismatch(result, _, _),
             let .renderCancelledAfterSubmission(result, _),
             let .renderResultMismatch(result, _),
             let .cancelledAfterRender(result, _),
             let .jpegEncodingFailed(result, _, _):
            result.finalCursor
        }
    }

    /// Derives exact cursor knowledge from a non-advancing current capture.
    private static func knownCursor(
        after outcome: OfflineCurrentCaptureOutcome,
        previous: SimulationCursor
    ) -> SimulationCursor {
        switch outcome {
        case let .completed(result):
            result.sourceSnapshot.cursor

        case .coordinatorBusy,
             .cancelledBeforeRender:
            previous

        case let .cursorMismatch(_, current):
            current

        case let .renderRejected(sourceSnapshot, _),
             let .renderFailed(sourceSnapshot, _),
             let .renderCancellationRequestIDMismatch(
                 sourceSnapshot,
                 _,
                 _
             ),
             let .renderCancelledAfterSubmission(sourceSnapshot, _),
             let .renderResultMismatch(sourceSnapshot, _),
             let .cancelledAfterRender(sourceSnapshot, _),
             let .jpegEncodingFailed(sourceSnapshot, _, _):
            sourceSnapshot.cursor
        }
    }

    /// Counts only retained encoded or raw image payloads by declared policy.
    private static func retainedImageByteCount(
        in outcome: AgentSessionExecutionOutcome
    ) -> Int {
        switch outcome {
        case let .capture(captureOutcome):
            return switch captureOutcome {
            case let .completed(result):
                result.artifact.encodedData.count

            case let .renderResultMismatch(_, renderResult),
                 let .cancelledAfterRender(_, renderResult),
                 let .jpegEncodingFailed(_, renderResult, _):
                renderResult.image.bytes.count

            case .coordinatorBusy,
                 .cancelledBeforeAdvance,
                 .advanceRejected,
                 .advanceResultMismatch,
                 .cancelledAfterAdvance,
                 .renderRejected,
                 .renderFailed,
                 .renderCancellationRequestIDMismatch,
                 .renderCancelledAfterSubmission:
                0
            }

        case let .currentCapture(captureOutcome):
            return switch captureOutcome {
            case let .completed(result):
                result.artifact.encodedData.count

            case let .renderResultMismatch(_, renderResult),
                 let .cancelledAfterRender(_, renderResult),
                 let .jpegEncodingFailed(_, renderResult, _):
                renderResult.image.bytes.count

            case .coordinatorBusy,
                 .cancelledBeforeRender,
                 .cursorMismatch,
                 .renderRejected,
                 .renderFailed,
                 .renderCancellationRequestIDMismatch,
                 .renderCancelledAfterSubmission:
                0
            }

        case .stepLimitExceeded:
            return 0
        }
    }
}
