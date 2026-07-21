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
