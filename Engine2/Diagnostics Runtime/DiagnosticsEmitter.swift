import Foundation
import OSLog

/// Emits stable Apple-system instrumentation and forwards compact typed samples.
///
/// Runtime owners call domain-specific methods so signpost names, public-field
/// policy, and sample construction stay centralized. The optional sink remains
/// the machine-readable source; unified logs and signposts are observational.
final class DiagnosticsEmitter {
    typealias TimeSource = () -> SuspendingClock.Instant

    let sessionID: DiagnosticsSessionID

    private let sessionStart: SuspendingClock.Instant
    private let sink: any PDiagnosticsSink
    private let timeSource: TimeSource

    init(
        sessionID: DiagnosticsSessionID = DiagnosticsSessionID(),
        sink: any PDiagnosticsSink = NoOpDiagnosticsSink(),
        timeSource: @escaping TimeSource = { SuspendingClock().now }
    ) {
        self.sessionID = sessionID
        self.sink = sink
        self.timeSource = timeSource
        self.sessionStart = timeSource()
    }

    /// Measures and reports one completed fixed step without changing its result.
    func measureSimulationStep<Result>(
        tick: SimulationTick,
        didRunSimulationSystems: Bool,
        operation: () throws -> Result
    ) rethrows -> Result {
        let start = timeSource()
        defer {
            let end = timeSource()
            record(
                category: .simulationLoop,
                timestampAt: end,
                payload: .simulationStep(
                    SimulationStepDiagnostics(
                        tick: tick,
                        didRunSimulationSystems: didRunSimulationSystems,
                        durationNanoseconds: start.duration(to: end).diagnosticsNanoseconds
                    )
                )
            )
        }

        let signposter = DiagnosticsOSHandles.signposter(for: .simulationLoop)
        guard signposter.isEnabled else {
            return try operation()
        }

        let signpostID = signposter.makeSignpostID()
        return try signposter.withIntervalSignpost(
            "SimulationStep",
            id: signpostID,
            "session=\(self.sessionID.rawValue.uuidString, privacy: .public) tick=\(tick.rawValue, privacy: .public) simulation=\(didRunSimulationSystems, privacy: .public)",
            around: operation
        )
    }

    /// Captures and reports the Simulation-owned presentation boundary once.
    func capturePresentationSnapshot(
        from world: World,
        at tick: SimulationTick
    ) -> SimulationPresentationSnapshot {
        let start = timeSource()
        let renderableRowCount = world.renderableComponents.dense.count
        let signposter = DiagnosticsOSHandles.signposter(for: .simulationSnapshot)
        let snapshot: SimulationPresentationSnapshot

        if signposter.isEnabled {
            let signpostID = signposter.makeSignpostID()
            snapshot = signposter.withIntervalSignpost(
                "PresentationSnapshotCapture",
                id: signpostID,
                "session=\(self.sessionID.rawValue.uuidString, privacy: .public) tick=\(tick.rawValue, privacy: .public) renderable_rows=\(renderableRowCount, privacy: .public)"
            ) {
                SimulationPresentationSnapshot.capture(from: world, at: tick)
            }
        } else {
            snapshot = SimulationPresentationSnapshot.capture(from: world, at: tick)
        }

        let end = timeSource()
        record(
            category: .simulationSnapshot,
            timestampAt: end,
            payload: .presentationSnapshot(
                PresentationSnapshotDiagnostics(
                    tick: tick,
                    renderableRowCount: renderableRowCount,
                    publishedPresentationCount: snapshot.entityPresentations.count,
                    durationNanoseconds: start.duration(to: end).diagnosticsNanoseconds
                )
            )
        )
        return snapshot
    }

    /// Measures one app-loop poll and records its fixed-step/backlog outcome.
    func measureSimulationPoll(
        sampledWallDelta: Duration,
        backlogBefore: Duration,
        operation: () -> Void,
        outcome: () -> (completedTick: SimulationTick, stepsCompleted: Int, backlogAfter: Duration)
    ) {
        let start = timeSource()
        let signposter = DiagnosticsOSHandles.signposter(for: .simulationLoop)

        if signposter.isEnabled {
            let signpostID = signposter.makeSignpostID()
            signposter.withIntervalSignpost(
                "SimulationPoll",
                id: signpostID,
                "session=\(self.sessionID.rawValue.uuidString, privacy: .public) wall_delta_ns=\(sampledWallDelta.diagnosticsNanoseconds, privacy: .public) backlog_before_ns=\(backlogBefore.diagnosticsNanoseconds, privacy: .public)",
                around: operation
            )
        } else {
            operation()
        }

        let result = outcome()
        let end = timeSource()
        record(
            category: .simulationLoop,
            timestampAt: end,
            payload: .simulationPoll(
                SimulationPollDiagnostics(
                    completedTick: result.completedTick,
                    sampledWallDeltaNanoseconds: sampledWallDelta.diagnosticsNanoseconds,
                    stepsCompleted: result.stepsCompleted,
                    backlogBeforeNanoseconds: backlogBefore.diagnosticsNanoseconds,
                    backlogAfterNanoseconds: result.backlogAfter.diagnosticsNanoseconds,
                    durationNanoseconds: start.duration(to: end).diagnosticsNanoseconds
                )
            )
        )
    }

    /// Records the start of an app-owned Simulation Runtime polling session.
    func logSimulationLoopStarted(pollInterval: Duration) {
        DiagnosticsOSHandles.logger(for: .simulationLoop).info(
            "event=simulation_loop_started session=\(self.sessionID.rawValue.uuidString, privacy: .public) poll_interval_ns=\(pollInterval.diagnosticsNanoseconds, privacy: .public)"
        )
    }

    /// Records an explicit owner-requested stop of the polling session.
    func logSimulationLoopStopped(completedTick: SimulationTick) {
        DiagnosticsOSHandles.logger(for: .simulationLoop).info(
            "event=simulation_loop_stopped session=\(self.sessionID.rawValue.uuidString, privacy: .public) tick=\(completedTick.rawValue, privacy: .public)"
        )
    }

    /// Records cancellation separately from the owner's stop request.
    func logSimulationLoopCancelled(completedTick: SimulationTick) {
        DiagnosticsOSHandles.logger(for: .simulationLoop).debug(
            "event=simulation_loop_cancelled session=\(self.sessionID.rawValue.uuidString, privacy: .public) tick=\(completedTick.rawValue, privacy: .public)"
        )
    }

    /// Records a handled catch-up threshold crossing without changing policy.
    func logSimulationBacklogHigh(
        completedTick: SimulationTick,
        stepsCompleted: Int,
        availableBacklog: Duration
    ) {
        DiagnosticsOSHandles.logger(for: .simulationLoop).notice(
            "event=simulation_backlog_high session=\(self.sessionID.rawValue.uuidString, privacy: .public) tick=\(completedTick.rawValue, privacy: .public) steps=\(stepsCompleted, privacy: .public) backlog_ns=\(availableBacklog.diagnosticsNanoseconds, privacy: .public)"
        )
    }

    /// Measures and reports one invariant system update in schedule order.
    func measureSystemUpdate<Result>(
        tick: SimulationTick,
        systemID: SimulationSystemID,
        scheduleLane: SimulationScheduleLane,
        executionOrder: Int,
        workCount: Int? = nil,
        operation: () throws -> Result
    ) rethrows -> Result {
        let start = timeSource()
        defer {
            let end = timeSource()
            record(
                category: .simulationSystem,
                timestampAt: end,
                payload: .systemUpdate(
                    SystemUpdateDiagnostics(
                        tick: tick,
                        systemID: systemID,
                        scheduleLane: scheduleLane,
                        executionOrder: executionOrder,
                        durationNanoseconds: start.duration(to: end).diagnosticsNanoseconds,
                        workCount: workCount
                    )
                )
            )
        }

        let signposter = DiagnosticsOSHandles.signposter(for: .simulationSystem)
        guard signposter.isEnabled else {
            return try operation()
        }

        let signpostID = signposter.makeSignpostID()
        return try signposter.withIntervalSignpost(
            "SystemUpdate",
            id: signpostID,
            "session=\(self.sessionID.rawValue.uuidString, privacy: .public) tick=\(tick.rawValue, privacy: .public) system=\(systemID.rawValue, privacy: .public) lane=\(scheduleLane.rawValue, privacy: .public) order=\(executionOrder, privacy: .public)",
            around: operation
        )
    }

    /// Forwards an already-typed fact without requiring a system-log assertion.
    func record(
        category: DiagnosticsCategory,
        payload: DiagnosticsSamplePayload
    ) {
        record(category: category, timestampAt: timeSource(), payload: payload)
    }

    /// Records low-frequency structural complexity at world construction.
    func recordSimulationRuntimeInventory(
        alwaysSystemIDs: [SimulationSystemID],
        simulationSystemIDs: [SimulationSystemID],
        componentStores: [ComponentStoreInventory],
        presentationEntityCount: Int
    ) {
        record(
            category: .simulationLoop,
            payload: .simulationRuntimeInventory(
                SimulationRuntimeInventoryDiagnostics(
                    alwaysSystemIDs: alwaysSystemIDs,
                    simulationSystemIDs: simulationSystemIDs,
                    componentStores: componentStores,
                    presentationEntityCount: presentationEntityCount
                )
            )
        )
    }

    private func record(
        category: DiagnosticsCategory,
        timestampAt instant: SuspendingClock.Instant,
        payload: DiagnosticsSamplePayload
    ) {
        sink.record(
            DiagnosticsSample(
                sessionID: sessionID,
                timestamp: DiagnosticsTimestamp(
                    nanosecondsSinceSessionStart: sessionStart
                        .duration(to: instant)
                        .diagnosticsNanoseconds
                ),
                category: category,
                payload: payload
            )
        )
    }
}
