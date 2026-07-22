import Observation

/// App-owned cadence authority for a real-time Simulation Runtime connection.
///
/// The driver translates elapsed wall time into exact, cursor-qualified
/// Simulation advance requests. It owns playback policy and polling lifecycle;
/// the target owns authoritative session state, exact step execution, and
/// publication of completed results.
@MainActor
@Observable
final class RealtimeAdvanceDriver {
    /// Factory that creates a fresh elapsed-time sampler for each driver run.
    typealias ClockFactory = () -> SystemClock

    /// Monotonic source used to schedule absolute polling deadlines.
    typealias TimeSource = () -> SystemClock.Instant

    /// Injectable suspension boundary that sleeps until an absolute deadline.
    typealias Sleeper = @Sendable (SystemClock.Instant) async throws -> Void

    /// Weakly resolving source used by the polling task between wake cycles.
    typealias DriverSource = @MainActor () -> RealtimeAdvanceDriver?

    let fixedTimeStep: Duration
    let pollInterval: Duration
    let catchUpPolicy: RealtimeCatchUpPolicy

    /// Whether elapsed time may currently become authoritative Simulation work.
    private(set) var isAdvancementEnabled: Bool

    /// Whether lifecycle policy currently permits this driver to poll.
    private(set) var isRunning = false

    /// Whether no exact request issued by this connection remains unsettled.
    private(set) var isQuiescent = true

    /// Latest authority fault. App coordination must synchronize before resume.
    private(set) var fault: RealtimeAdvanceDriverFault?

    @ObservationIgnored
    private let advanceTarget: any PSimulationAdvanceTarget

    @ObservationIgnored
    private weak var inputSource: (any PInputSnapshotSource)?

    @ObservationIgnored
    private let clockFactory: ClockFactory

    @ObservationIgnored
    private let scheduleTimeSource: TimeSource

    @ObservationIgnored
    private let sleeper: Sleeper

    @ObservationIgnored
    private var clock: SystemClock?

    @ObservationIgnored
    private var elapsedRemainder = Duration.zero

    @ObservationIgnored
    private var expectedCursor: SimulationCursor

    @ObservationIgnored
    private var transitionInputBaseline: InputSnapshot?

    @ObservationIgnored
    private var discardNextElapsedSample = false

    @ObservationIgnored
    private var runID: UInt64 = 0

    @ObservationIgnored
    private var updateTask: Task<Void, Never>?

    @ObservationIgnored
    private var restartRequested = false

    @ObservationIgnored
    private var synchronizationGeneration: UInt64 = 0

    @ObservationIgnored
    private var inputPolicyGeneration: UInt64 = 0

    @ObservationIgnored
    private var advanceDrainWaiters: [CheckedContinuation<Void, Never>] = []

    init(
        advanceTarget: any PSimulationAdvanceTarget,
        inputSource: (any PInputSnapshotSource)? = nil,
        initialCursor: SimulationCursor,
        fixedTimeStep: Duration,
        pollInterval: Duration? = nil,
        catchUpPolicy: RealtimeCatchUpPolicy = .interactive,
        isAdvancementEnabled: Bool = true,
        clockFactory: @escaping ClockFactory = { SystemClock() },
        scheduleTimeSource: @escaping TimeSource = { SuspendingClock().now },
        sleeper: @escaping Sleeper = { deadline in
            try await SuspendingClock().sleep(until: deadline)
        }
    ) {
        precondition(
            fixedTimeStep > .zero,
            "Real-time advancement requires a positive fixed time step."
        )

        let resolvedPollInterval = pollInterval ?? fixedTimeStep
        precondition(
            resolvedPollInterval > .zero,
            "Real-time advancement requires a positive poll interval."
        )

        self.advanceTarget = advanceTarget
        self.inputSource = inputSource
        self.expectedCursor = initialCursor
        self.fixedTimeStep = fixedTimeStep
        self.pollInterval = resolvedPollInterval
        self.catchUpPolicy = catchUpPolicy
        self.isAdvancementEnabled = isAdvancementEnabled
        self.clockFactory = clockFactory
        self.scheduleTimeSource = scheduleTimeSource
        self.sleeper = sleeper
    }

    /// Starts polling if this driver does not already own a live task.
    func start() {
        guard isRunning == false else {
            return
        }

        isRunning = true
        if isAdvancementEnabled {
            captureTransitionInputBaseline()
        }

        // A cancelled task may still be awaiting a target that ignores
        // cancellation. Queue the restart until that sole authority retires so
        // two requests can never overlap on this connection.
        guard updateTask == nil else {
            restartRequested = true
            return
        }

        launchRun()
    }

    /// Cancels polling and discards elapsed work that has not been requested.
    func stop() {
        guard isRunning else {
            clock = nil
            elapsedRemainder = .zero
            return
        }

        isRunning = false
        restartRequested = false
        advanceRunID()
        updateTask?.cancel()
        clock = nil
        elapsedRemainder = .zero
        discardNextElapsedSample = false
    }

    /// Revokes future requests and waits for any already-issued exact request.
    ///
    /// Cancellation cannot roll back authoritative work already accepted by a
    /// target. App lifecycle and destructive session transitions use this
    /// boundary before reporting the connection fully stopped or replacing its
    /// world.
    func stopAndDrain() async {
        stop()

        guard isQuiescent == false else {
            return
        }

        await withCheckedContinuation { continuation in
            // MainActor serialization closes the race between the guard and
            // registering this waiter.
            if isQuiescent == false {
                advanceDrainWaiters.append(continuation)
            } else {
                continuation.resume()
            }
        }
    }

    /// Allows future elapsed samples to produce Simulation advances.
    func resumeAdvancement() {
        guard isAdvancementEnabled == false, fault == nil else {
            return
        }

        isAdvancementEnabled = true
        elapsedRemainder = .zero
        captureTransitionInputBaseline()

        // A resume that occurs before the next disabled wake must still drop
        // the interval spanning the pause. The baseline captured above travels
        // with the next publication so active input survives without replaying
        // cumulative transients from the inactive interval.
        discardNextElapsedSample = true
    }

    /// Prevents future advances and permanently drops any partial-step backlog.
    func pauseAdvancement() {
        guard isAdvancementEnabled else {
            return
        }

        isAdvancementEnabled = false
        elapsedRemainder = .zero
        setTransitionInputBaseline(nil)

        // If pause and resume both occur before another wake, that wake must
        // still discard time spanning the disabled interval.
        discardNextElapsedSample = true
    }

    /// Re-establishes the cursor contract after an App-coordinated lifecycle
    /// transition such as rebuilding or replacing the Simulation session.
    ///
    /// Synchronizing clears any prior authority fault but deliberately preserves
    /// the user's enabled/paused preference. A faulted driver therefore remains
    /// paused until the App explicitly resumes it.
    func synchronize(
        to cursor: SimulationCursor,
        inputBaseline: InputSnapshot? = nil
    ) {
        precondition(
            synchronizationGeneration < .max,
            "Real-time synchronization generation exhausted."
        )
        synchronizationGeneration += 1
        expectedCursor = cursor
        setTransitionInputBaseline(
            inputBaseline ?? inputSource?.latestInputSnapshot
        )
        elapsedRemainder = .zero
        discardNextElapsedSample = true
        fault = nil
    }

    /// Launches the one polling task after any retiring request has settled.
    private func launchRun() {
        precondition(updateTask == nil)

        // A fresh clock discards all wall time outside this lifecycle run.
        clock = clockFactory()
        elapsedRemainder = .zero
        discardNextElapsedSample = false
        advanceRunID()

        let currentRunID = runID
        let firstWakeDeadline = scheduleTimeSource().advanced(by: pollInterval)
        let driverSource: DriverSource = { [weak self] in self }
        updateTask = Task { @MainActor in
            await Self.runLoop(
                driverSource: driverSource,
                runID: currentRunID,
                nextWakeDeadline: firstWakeDeadline
            )
        }
    }

    /// Sleeps without retaining the driver, reacquiring it only to process a wake.
    private static func runLoop(
        driverSource: @escaping DriverSource,
        runID: UInt64,
        nextWakeDeadline initialWakeDeadline: SystemClock.Instant
    ) async {
        var nextWakeDeadline = initialWakeDeadline

        defer {
            driverSource()?.finishRun(runID: runID)
        }

        while Task.isCancelled == false {
            guard let sleeper = driverSource()?.sleeper else {
                return
            }

            do {
                // Absolute deadlines prevent ordinary wake jitter from
                // accumulating into long-term cadence drift.
                try await sleeper(nextWakeDeadline)
            } catch {
                return
            }

            let followingDeadline: SystemClock.Instant?
            do {
                // Limit the strong reference to wake processing. In particular,
                // the next sleeper suspension must not keep an otherwise
                // unowned configuration assembly alive indefinitely.
                guard let driver = driverSource() else {
                    return
                }
                followingDeadline = await driver.processWake(
                    runID: runID,
                    previousDeadline: nextWakeDeadline
                )
            }

            guard let followingDeadline else {
                return
            }
            nextWakeDeadline = followingDeadline
        }
    }

    /// Processes one elapsed-time sample and optionally issues one exact batch.
    private func processWake(
        runID: UInt64,
        previousDeadline: SystemClock.Instant
    ) async -> SystemClock.Instant? {
        // Cancellation-insensitive test or platform sleepers may return after
        // stop/restart. Revalidate this run before sampling or asking the
        // authoritative target to do any work.
        guard Task.isCancelled == false, self.runID == runID else {
            return nil
        }

        guard var clock else {
            return nil
        }

        let elapsed = clock.consumeDeltaTime()
        self.clock = clock

        if isAdvancementEnabled == false || discardNextElapsedSample {
            // Paused time and any pre-pause fractional step are not debt.
            elapsedRemainder = .zero
            discardNextElapsedSample = false
            return advancedDeadline(after: previousDeadline)
        }

        elapsedRemainder += elapsed

        guard let stepCount = consumeReadyStepCount() else {
            return advancedDeadline(after: previousDeadline)
        }

        // Read the latest-value source once so input and step count remain one
        // immutable, attributable request across the async boundary.
        let inputSnapshot = inputSource?.latestInputSnapshot
        let inputAssignment: SimulationInputAssignment
        switch (transitionInputBaseline, inputSnapshot) {
        case let (.some(baseline), .some(snapshot)):
            inputAssignment = .rebaseThenIngest(
                baseline: baseline,
                snapshot: snapshot
            )

        case let (.some(baseline), .none):
            inputAssignment = .rebase(baseline)

        case let (.none, .some(snapshot)):
            inputAssignment = .ingest(snapshot)

        case (.none, .none):
            inputAssignment = .none
        }

        let request = SimulationAdvanceRequest(
            expectedCursor: expectedCursor,
            stepCount: stepCount,
            inputAssignment: inputAssignment
        )
        let requestSynchronizationGeneration = synchronizationGeneration
        let requestInputPolicyGeneration = inputPolicyGeneration

        // No suspension occurs between the wake validation above and this
        // request, but keep the authority check adjacent to the mutation
        // boundary so that invariant remains explicit.
        guard Task.isCancelled == false, self.runID == runID else {
            return nil
        }

        isQuiescent = false
        let outcome = await advanceTarget.advance(request)
        finishInFlightAdvance()

        // Apply committed bookkeeping before checking run cancellation. A
        // stop may cancel transport but cannot undo target work. Explicit
        // synchronization and newer input policy always supersede an old
        // request's result through their independent generations.
        if case let .completed(result) = outcome {
            if requestSynchronizationGeneration == synchronizationGeneration {
                expectedCursor = result.finalCursor
            }
            if requestInputPolicyGeneration == inputPolicyGeneration {
                transitionInputBaseline = nil
            }
        }

        // A stopped task may still receive a result from a target that did not
        // cooperate with cancellation. Its safe committed bookkeeping was
        // applied above; it must not continue the retired run.
        guard Task.isCancelled == false, self.runID == runID else {
            return nil
        }

        switch outcome {
        case .completed:
            break

        case let .rejected(.cursorMismatch(expected, current)):
            // Ignore a reply made obsolete by an explicit App-owned
            // synchronization while the directed request was in flight.
            guard requestSynchronizationGeneration == synchronizationGeneration else {
                return nil
            }

            // A mismatch means this supposedly exclusive authority no longer
            // understands the target timeline. Surface the fault and stop
            // rather than silently adopting potentially unrelated state. The
            // App may synchronize after coordinating the cause.
            fault = .cursorMismatch(expected: expected, current: current)
            isAdvancementEnabled = false
            isRunning = false
            elapsedRemainder = .zero
            setTransitionInputBaseline(nil)
            return nil
        }

        return advancedDeadline(after: previousDeadline)
    }

    /// Releases the one task slot and launches a queued replacement if needed.
    private func finishRun(runID: UInt64) {
        updateTask = nil
        clock = nil

        if restartRequested, isRunning {
            restartRequested = false
            launchRun()
        } else if self.runID == runID {
            isRunning = false
        }
    }

    /// Removes at most one configured wake budget from elapsed-time debt.
    private func consumeReadyStepCount() -> SimulationStepCount? {
        guard elapsedRemainder >= fixedTimeStep else {
            return nil
        }

        var rawStepCount: UInt32 = 0
        let maximumStepCount = catchUpPolicy.maximumStepsPerWake.rawValue
        while elapsedRemainder >= fixedTimeStep,
              rawStepCount < maximumStepCount {
            elapsedRemainder -= fixedTimeStep
            rawStepCount += 1
        }

        if elapsedRemainder >= fixedTimeStep,
           catchUpPolicy.backlogTreatment == .discardOverflow {
            // Once at least one additional whole step overflows the cap, real-
            // time responsiveness wins over wall-clock catch-up. Cursor space
            // remains contiguous because no Simulation step was requested or
            // skipped; only external elapsed-time debt is discarded.
            elapsedRemainder = .zero
        }

        return SimulationStepCount(rawValue: rawStepCount)
    }

    /// Returns the first configured deadline strictly after the current time.
    private func advancedDeadline(
        after previousDeadline: SystemClock.Instant
    ) -> SystemClock.Instant {
        var nextWakeDeadline = previousDeadline.advanced(by: pollInterval)
        let currentTime = scheduleTimeSource()

        while currentTime.duration(to: nextWakeDeadline) <= .zero {
            nextWakeDeadline = nextWakeDeadline.advanced(by: pollInterval)
        }

        return nextWakeDeadline
    }

    /// Captures the cutover publication immediately, before later active input.
    private func captureTransitionInputBaseline() {
        setTransitionInputBaseline(inputSource?.latestInputSnapshot)
    }

    /// Invalidates stale task work without allowing identity wraparound.
    private func advanceRunID() {
        precondition(runID < .max, "Real-time driver run identity exhausted.")
        runID += 1
    }

    /// Changes input policy while superseding any in-flight request bookkeeping.
    private func setTransitionInputBaseline(_ baseline: InputSnapshot?) {
        precondition(
            inputPolicyGeneration < .max,
            "Real-time input policy generation exhausted."
        )
        inputPolicyGeneration += 1
        transitionInputBaseline = baseline
    }

    /// Releases lifecycle waiters after one accepted target request settles.
    private func finishInFlightAdvance() {
        isQuiescent = true

        let waiters = advanceDrainWaiters
        advanceDrainWaiters.removeAll(keepingCapacity: true)
        for waiter in waiters {
            waiter.resume()
        }
    }

    deinit {
        updateTask?.cancel()
    }
}
