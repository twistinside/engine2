//
//  AppEngineLoop.swift
//  Engine2
//
//  Created by Codex on 3/15/26.
//

/// Owns the app-level async task that polls wall time and advances the engine.
///
/// This sits above `Engine`: the app decides when the simulation loop should
/// run, while `Engine` still owns fixed-step accumulation and system order.
@MainActor
final class AppEngineLoop {
    typealias ClockFactory = () -> SystemClock
    typealias Sleeper = @Sendable (Duration) async throws -> Void

    let engine: Engine
    let pollInterval: Duration

    private let clockFactory: ClockFactory
    private let sleeper: Sleeper

    private var clock: SystemClock?
    private var runID: UInt64 = 0
    private var updateTask: Task<Void, Never>?

    var isRunning: Bool {
        updateTask != nil
    }

    init(
        engine: Engine = Engine(),
        pollInterval: Duration? = nil,
        clockFactory: @escaping ClockFactory = { SystemClock() },
        sleeper: @escaping Sleeper = { duration in
            try await SuspendingClock().sleep(for: duration)
        }
    ) {
        self.engine = engine
        self.pollInterval = pollInterval ?? engine.fixedTimeStep
        self.clockFactory = clockFactory
        self.sleeper = sleeper
        self.clock = nil

        precondition(self.pollInterval > .zero, "AppEngineLoop requires a positive poll interval")
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

        let currentRunID = runID
        updateTask = Task { @MainActor [weak self] in
            await self?.runLoop(runID: currentRunID)
        }
    }

    /// Cancels the current update task, if one exists.
    func stop() {
        runID += 1
        updateTask?.cancel()
        updateTask = nil
        clock = nil
    }

    private func runLoop(runID: UInt64) async {
        defer {
            // Ignore cleanup from an older task if a newer run has already started.
            if self.runID == runID {
                updateTask = nil
            }
        }

        while !Task.isCancelled {
            do {
                try await sleeper(pollInterval)
            } catch {
                return
            }

            guard var clock else {
                return
            }

            engine.update(deltaTime: clock.consumeDeltaTime())
            self.clock = clock
        }
    }

    deinit {
        updateTask?.cancel()
    }
}
