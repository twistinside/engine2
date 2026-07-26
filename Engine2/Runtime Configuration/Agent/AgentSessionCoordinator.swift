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
    private var highestAcceptedSequence: AgentSessionRequestSequence?
    private var activeRequest: AgentCaptureRequest?
    private var isClosed = false
    private var replayCache: AgentSessionReplayCache
    private var drainWaiters: [CheckedContinuation<Void, Never>] = []

    /// Creates one session around the already composed offline workflow.
    init(
        sessionID: AgentSessionID,
        initialCursor: SimulationCursor,
        limits: AgentSessionLimits,
        captureTarget: any POfflineCaptureTarget,
        initialRequestSequence: AgentSessionRequestSequence
    ) {
        self.sessionID = sessionID
        self.knownCursor = initialCursor
        self.limits = limits
        self.captureTarget = captureTarget
        self.nextExpectedSequence = initialRequestSequence
        self.replayCache = AgentSessionReplayCache(
            maximumResultCount: limits.maximumRetainedResultCount,
            maximumImageBytes: limits.maximumRetainedImageBytes
        )
    }

    /// Admits, executes once, replays, or refuses one stable request value.
    func capture(_ request: AgentCaptureRequest) async -> AgentSessionSubmissionOutcome {
        guard request.id.sessionID == sessionID else {
            return rejected(
                .wrongSession(
                    expected: sessionID,
                    actual: request.id.sessionID
                )
            )
        }

        // Retained replay and payload conflict take precedence even after close.
        if let replayEntry = replayCache.entry(for: request.id) {
            guard replayEntry.request == request else {
                return rejected(.requestConflict(request.id))
            }
            return .replayed(replayEntry.response)
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
                knownCursor = outcome.authoritativeCursor(after: knownCursor)
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
            knownCursor = outcome.authoritativeCursor(after: knownCursor)
            response = AgentSessionResponse(
                requestID: request.id,
                outcome: .currentCapture(outcome),
                knownCursor: knownCursor
            )
        }

        replayCache.retain(
            AgentSessionReplayEntry(
                request: request,
                response: response
            )
        )
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
    private func rejected(_ reason: AgentSessionRequestRejectionReason) -> AgentSessionSubmissionOutcome {
        .rejected(
            AgentSessionRequestRejection(
                reason: reason,
                knownCursor: knownCursor
            )
        )
    }

    /// Resumes every closer only after accepted work reaches a terminal value.
    private func resumeDrainWaiters() {
        let waiters = drainWaiters
        drainWaiters.removeAll()
        for waiter in waiters {
            waiter.resume()
        }
    }
}
