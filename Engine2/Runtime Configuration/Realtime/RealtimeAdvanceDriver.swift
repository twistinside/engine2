import Observation

/// Assembly-owned cadence authority for a real-time Simulation Runtime connection.
///
/// The driver translates elapsed wall time into exact, cursor-qualified
/// Simulation advance requests. It owns playback policy and polling lifecycle;
/// the target owns authoritative session state, exact step execution, and
/// publication of completed results.
@Observable
final class RealtimeAdvanceDriver {
    var fixedTimeStep: Duration {
        stepAccumulator.fixedTimeStep
    }

    let pollInterval: Duration

    var catchUpPolicy: RealtimeCatchUpPolicy {
        stepAccumulator.catchUpPolicy
    }

    /// User policy or authority fault controlling whether elapsed time advances.
    private(set) var advancementState: RealtimeAdvancementState

    /// Whether lifecycle policy currently permits this driver to poll.
    private(set) var isRunning = false

    /// Whether no exact request issued by this connection remains unsettled.
    private(set) var isQuiescent = true

    /// Whether elapsed time may currently become authoritative Simulation work.
    var isAdvancementEnabled: Bool {
        advancementState == .enabled
    }

    /// Latest authority fault. Assembly coordination must synchronize before resume.
    var fault: RealtimeAdvanceDriverFault? {
        guard case let .faulted(fault) = advancementState else {
            return nil
        }
        return fault
    }

    @ObservationIgnored
    private let advanceTarget: any PSimulationAdvanceTarget

    @ObservationIgnored
    private weak var inputSource: (any PInputSnapshotSource)?

    @ObservationIgnored
    private let clock: any PRealtimeClock

    @ObservationIgnored
    private var previousElapsedSample: SuspendingClock.Instant?

    @ObservationIgnored
    private var stepAccumulator: RealtimeStepAccumulator

    @ObservationIgnored
    private var expectedCursor: SimulationCursor

    @ObservationIgnored
    private var inputAssignmentState = RealtimeInputAssignmentState()

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
    private var advanceDrainWaiters: [CheckedContinuation<Void, Never>] = []

    /// Creates the production cadence connection using suspending-clock timing.
    convenience init(
        advanceTarget: any PSimulationAdvanceTarget,
        inputSource: (any PInputSnapshotSource)?,
        initialCursor: SimulationCursor,
        fixedTimeStep: Duration,
        pollInterval: Duration,
        catchUpPolicy: RealtimeCatchUpPolicy,
        isAdvancementEnabled: Bool
    ) {
        let clock = SuspendingRealtimeClock()
        self.init(
            advanceTarget: advanceTarget,
            inputSource: inputSource,
            initialCursor: initialCursor,
            fixedTimeStep: fixedTimeStep,
            pollInterval: pollInterval,
            catchUpPolicy: catchUpPolicy,
            isAdvancementEnabled: isAdvancementEnabled,
            clock: clock
        )
    }

    /// Creates a cadence connection with one coherent time dependency.
    ///
    /// Tests and specialized hosts may control sampling and suspension, but
    /// both operations deliberately remain coupled to one monotonic clock.
    init(
        advanceTarget: any PSimulationAdvanceTarget,
        inputSource: (any PInputSnapshotSource)?,
        initialCursor: SimulationCursor,
        fixedTimeStep: Duration,
        pollInterval: Duration,
        catchUpPolicy: RealtimeCatchUpPolicy,
        isAdvancementEnabled: Bool,
        clock: any PRealtimeClock
    ) {
        precondition(fixedTimeStep > .zero, "Real-time advancement requires a positive fixed time step.")
        precondition(pollInterval > .zero, "Real-time advancement requires a positive poll interval.")

        self.advanceTarget = advanceTarget
        self.inputSource = inputSource
        self.expectedCursor = initialCursor
        self.pollInterval = pollInterval
        self.stepAccumulator = RealtimeStepAccumulator(
            fixedTimeStep: fixedTimeStep,
            catchUpPolicy: catchUpPolicy
        )
        self.advancementState = isAdvancementEnabled ? .enabled : .paused
        self.clock = clock
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
            previousElapsedSample = nil
            stepAccumulator.reset()
            return
        }

        isRunning = false
        restartRequested = false
        advanceRunID()
        updateTask?.cancel()
        previousElapsedSample = nil
        stepAccumulator.reset()
        discardNextElapsedSample = false
    }

    /// Revokes future requests and waits for any already-issued exact request.
    ///
    /// Cancellation cannot roll back authoritative work already accepted by a
    /// target. Assembly lifecycle and destructive session transitions use this
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
        guard advancementState == .paused else {
            return
        }

        advancementState = .enabled
        stepAccumulator.reset()
        captureTransitionInputBaseline()

        // A resume that occurs before the next disabled wake must still drop
        // the interval spanning the pause. The baseline captured above travels
        // with the next publication so active input survives without replaying
        // cumulative transients from the inactive interval.
        discardNextElapsedSample = true
    }

    /// Prevents future advances and permanently drops any partial-step backlog.
    func pauseAdvancement() {
        guard advancementState == .enabled else {
            return
        }

        advancementState = .paused
        stepAccumulator.reset()
        setTransitionInputBaseline(nil)

        // If pause and resume both occur before another wake, that wake must
        // still discard time spanning the disabled interval.
        discardNextElapsedSample = true
    }

    /// Re-establishes the cursor contract after an assembly-coordinated lifecycle
    /// transition such as rebuilding or replacing the Simulation session.
    ///
    /// Synchronizing clears any prior authority fault but deliberately preserves
    /// the user's enabled/paused preference. A faulted driver therefore remains
    /// paused until its assembly explicitly resumes it.
    func synchronize(to cursor: SimulationCursor, inputBaseline: InputSnapshot?) {
        precondition(synchronizationGeneration < .max, "Real-time synchronization generation exhausted.")
        synchronizationGeneration += 1
        expectedCursor = cursor
        setTransitionInputBaseline(
            inputBaseline ?? inputSource?.latestInputSnapshot
        )
        stepAccumulator.reset()
        discardNextElapsedSample = true
        if case .faulted = advancementState {
            advancementState = .paused
        }
    }

    /// Launches the one polling task after any retiring request has settled.
    private func launchRun() {
        precondition(updateTask == nil)

        // A fresh baseline discards all wall time outside this lifecycle run.
        let launchInstant = clock.now
        previousElapsedSample = launchInstant
        stepAccumulator.reset()
        discardNextElapsedSample = false
        advanceRunID()

        let currentRunID = runID
        let firstWakeDeadline = launchInstant.advanced(by: pollInterval)
        updateTask = Task { [weak self] in
            var nextWakeDeadline = firstWakeDeadline

            defer {
                self?.finishRun(runID: currentRunID)
            }

            while Task.isCancelled == false {
                guard let clock = self?.clock else {
                    return
                }

                do {
                    // Absolute deadlines prevent ordinary wake jitter from
                    // accumulating into long-term cadence drift.
                    try await clock.sleep(until: nextWakeDeadline)
                } catch {
                    return
                }

                let followingDeadline: SuspendingClock.Instant?
                do {
                    // Limit the strong reference to wake processing. In particular,
                    // the next clock suspension must not keep an otherwise
                    // unowned configuration assembly alive indefinitely.
                    guard let driver = self else {
                        return
                    }
                    followingDeadline = await driver.processWake(
                        runID: currentRunID,
                        previousDeadline: nextWakeDeadline
                    )
                }

                guard let followingDeadline else {
                    return
                }
                nextWakeDeadline = followingDeadline
            }
        }
    }

    /// Processes one elapsed-time sample and optionally issues one exact batch.
    private func processWake(runID: UInt64, previousDeadline: SuspendingClock.Instant) async -> SuspendingClock.Instant? {
        // A cancellation-insensitive test clock may return after
        // stop/restart. Revalidate this run before sampling or asking the
        // authoritative target to do any work.
        guard Task.isCancelled == false, self.runID == runID else {
            return nil
        }

        guard let previousElapsedSample else {
            return nil
        }

        let currentElapsedSample = clock.now
        let elapsed = max(.zero, previousElapsedSample.duration(to: currentElapsedSample))
        self.previousElapsedSample = currentElapsedSample

        if isAdvancementEnabled == false || discardNextElapsedSample {
            // Paused time and any pre-pause fractional step are not debt.
            stepAccumulator.reset()
            discardNextElapsedSample = false
            return advancedDeadline(after: previousDeadline)
        }

        guard let stepCount = stepAccumulator.consumeSteps(adding: elapsed) else {
            return advancedDeadline(after: previousDeadline)
        }

        // Read the latest-value source once so input and step count remain one
        // immutable, attributable request across the async boundary.
        let inputSnapshot = inputSource?.latestInputSnapshot
        let requestInputAssignmentState = inputAssignmentState
        let inputAssignment = requestInputAssignmentState.assignment(
            ingesting: inputSnapshot
        )

        let request = SimulationAdvanceRequest(
            expectedCursor: expectedCursor,
            stepCount: stepCount,
            inputAssignment: inputAssignment
        )
        let requestSynchronizationGeneration = synchronizationGeneration

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
            inputAssignmentState.retireTransitionBaseline(
                ifUnchangedSince: requestInputAssignmentState
            )
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
            // Ignore a reply made obsolete by an explicit assembly-owned
            // synchronization while the directed request was in flight.
            guard requestSynchronizationGeneration == synchronizationGeneration else {
                return nil
            }

            // A mismatch means this supposedly exclusive authority no longer
            // understands the target timeline. Surface the fault and stop
            // rather than silently adopting potentially unrelated state. The
            // The assembly may synchronize after coordinating the cause.
            advancementState = .faulted(.cursorMismatch(expected: expected, current: current))
            isRunning = false
            stepAccumulator.reset()
            setTransitionInputBaseline(nil)
            return nil
        }

        return advancedDeadline(after: previousDeadline)
    }

    /// Releases the one task slot and launches a queued replacement if needed.
    private func finishRun(runID: UInt64) {
        updateTask = nil
        previousElapsedSample = nil

        if restartRequested, isRunning {
            restartRequested = false
            launchRun()
        } else if self.runID == runID {
            isRunning = false
        }
    }

    /// Returns the first configured deadline strictly after the current time.
    private func advancedDeadline(after previousDeadline: SuspendingClock.Instant) -> SuspendingClock.Instant {
        var nextWakeDeadline = previousDeadline.advanced(by: pollInterval)
        let currentTime = clock.now

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
        inputAssignmentState.replaceTransitionBaseline(baseline)
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
