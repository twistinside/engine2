/// Owns the async task that polls wall time and advances the engine.
///
/// This sits above `Engine`: a higher-level owner decides when the simulation
/// loop should run, while `Engine` still owns fixed-step accumulation and
/// system order.
@MainActor
final class SimulationLoop {
    /// Factory that creates a fresh elapsed-time sampler for each loop session.
    typealias ClockFactory = () -> SystemClock

    /// Monotonic source used to schedule the next asynchronous poll.
    typealias TimeSource = () -> SystemClock.Instant

    /// Injectable suspension boundary that sleeps until the requested instant.
    typealias Sleeper = @Sendable (SystemClock.Instant) async throws -> Void

    /// Main-actor notification emitted when the polling task starts or stops.
    typealias RunningStateDidChange = @MainActor (Bool) -> Void

    /// Main-actor notification carrying the latest completed simulation tick.
    typealias FixedStepsDidComplete = @MainActor (SimulationTick) -> Void

    let engine: Engine
    let pollInterval: Duration

    private let clockFactory: ClockFactory
    private let diagnostics: DiagnosticsEmitter
    private let backlogNoticeThreshold: Duration
    private let scheduleTimeSource: TimeSource
    private let sleeper: Sleeper
    private weak var inputSource: (any PInputSnapshotSource)?

    private var clock: SystemClock?
    private var runID: UInt64 = 0
    private var isBacklogAboveNoticeThreshold = false
    private var updateTask: Task<Void, Never>?

    var runningStateDidChange: RunningStateDidChange?
    var fixedStepsDidComplete: FixedStepsDidComplete?

    var isRunning: Bool {
        updateTask != nil
    }

    init(
        engine: Engine = Engine(),
        diagnostics: DiagnosticsEmitter = DiagnosticsEmitter(),
        inputSource: (any PInputSnapshotSource)? = nil,
        pollInterval: Duration? = nil,
        backlogNoticeThreshold: Duration? = nil,
        clockFactory: @escaping ClockFactory = { SystemClock() },
        scheduleTimeSource: @escaping TimeSource = { SuspendingClock().now },
        sleeper: @escaping Sleeper = { deadline in
            try await SuspendingClock().sleep(until: deadline)
        }
    ) {
        self.engine = engine
        self.diagnostics = diagnostics
        self.inputSource = inputSource
        self.pollInterval = pollInterval ?? engine.fixedTimeStep
        self.backlogNoticeThreshold = backlogNoticeThreshold ?? engine.fixedTimeStep * 4
        self.clockFactory = clockFactory
        self.scheduleTimeSource = scheduleTimeSource
        self.sleeper = sleeper
        self.clock = nil

        precondition(self.pollInterval > .zero, "SimulationLoop requires a positive poll interval")
        precondition(
            self.backlogNoticeThreshold > .zero,
            "SimulationLoop requires a positive backlog notice threshold"
        )
    }

    /// Starts the app-owned update task if it is not already running.
    func start() {
        guard updateTask == nil else {
            return
        }

        // Rebase wall-clock sampling when the app becomes active so inactive
        // time does not get replayed into the simulation on resume.
        clock = clockFactory()
        runID += 1
        isBacklogAboveNoticeThreshold = false

        let currentRunID = runID
        let firstWakeDeadline = scheduleTimeSource().advanced(by: pollInterval)
        updateTask = Task { @MainActor [weak self] in
            await self?.runLoop(
                runID: currentRunID,
                nextWakeDeadline: firstWakeDeadline
            )
        }
        diagnostics.logSimulationLoopStarted(pollInterval: pollInterval)
        runningStateDidChange?(true)
    }

    /// Cancels the current update task, if one exists.
    func stop() {
        guard updateTask != nil else {
            clock = nil
            return
        }

        runID += 1
        updateTask?.cancel()
        updateTask = nil
        clock = nil
        isBacklogAboveNoticeThreshold = false
        diagnostics.logSimulationLoopStopped(completedTick: engine.completedTick)
        runningStateDidChange?(false)
    }

    private func runLoop(
        runID: UInt64,
        nextWakeDeadline initialWakeDeadline: SystemClock.Instant
    ) async {
        var nextWakeDeadline = initialWakeDeadline

        defer {
            // Ignore cleanup from an older task if a newer run has already started.
            if self.runID == runID {
                updateTask = nil
                runningStateDidChange?(false)
            }
        }

        while !Task.isCancelled {
            do {
                // Sleep until the next absolute deadline instead of repeatedly
                // sleeping for a fixed relative interval. That avoids turning
                // normal wake-up jitter into long-term drift that forces extra
                // catch-up steps.
                try await sleeper(nextWakeDeadline)
            } catch {
                if error is CancellationError {
                    diagnostics.logSimulationLoopCancelled(
                        completedTick: engine.completedTick
                    )
                }
                return
            }

            guard var clock else {
                return
            }

            let completedTick = pollOnce(using: &clock)
            self.clock = clock

            // Latest-value publication only needs the final completed state
            // when one polling update catches up through multiple fixed steps.
            if let completedTick {
                fixedStepsDidComplete?(completedTick)
            }
            nextWakeDeadline = advancedDeadline(after: nextWakeDeadline)
        }
    }

    /// Performs one deterministic polling update using the supplied clock.
    ///
    /// Exposing this narrow operation lets tests exercise zero-step, one-step,
    /// and catch-up cadence without depending on task scheduling.
    @discardableResult
    func pollOnce(using clock: inout SystemClock) -> SimulationTick? {
        let sampledWallDelta = clock.consumeDeltaTime()
        let backlogBefore = engine.accumulatedTime
        let previousTick = engine.completedTick

        diagnostics.measureSimulationPoll(
            sampledWallDelta: sampledWallDelta,
            backlogBefore: backlogBefore,
            operation: {
                engine.update(
                    deltaTime: sampledWallDelta,
                    inputSnapshot: inputSource?.latestInputSnapshot
                )
            },
            outcome: {
                (
                    completedTick: engine.completedTick,
                    stepsCompleted: Int(engine.completedTick.rawValue - previousTick.rawValue),
                    backlogAfter: engine.accumulatedTime
                )
            }
        )

        let availableBacklog = backlogBefore + sampledWallDelta
        let isBacklogHigh = availableBacklog >= backlogNoticeThreshold
        if isBacklogHigh && !isBacklogAboveNoticeThreshold {
            diagnostics.logSimulationBacklogHigh(
                completedTick: engine.completedTick,
                stepsCompleted: Int(engine.completedTick.rawValue - previousTick.rawValue),
                availableBacklog: availableBacklog
            )
        }
        isBacklogAboveNoticeThreshold = isBacklogHigh

        return engine.completedTick == previousTick ? nil : engine.completedTick
    }

    /// Advances to the first future deadline after the current wall-clock time.
    private func advancedDeadline(after previousDeadline: SystemClock.Instant) -> SystemClock.Instant {
        var nextWakeDeadline = previousDeadline.advanced(by: pollInterval)
        let currentTime = scheduleTimeSource()

        while currentTime.duration(to: nextWakeDeadline) <= .zero {
            nextWakeDeadline = nextWakeDeadline.advanced(by: pollInterval)
        }

        return nextWakeDeadline
    }

    deinit {
        updateTask?.cancel()
    }
}
