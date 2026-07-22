import Foundation
import OSLog

/// Thread-safe completion bridge from Metal feedback to MainActor retention.
nonisolated final class GPUFrameCompletion: @unchecked Sendable {
    private weak var emitter: DiagnosticsEmitter?
    private let measurement: GPUFrameDiagnostics
    private let sessionStart: SuspendingClock.Instant
    private let start: SuspendingClock.Instant
    private let signpostState: OSSignpostIntervalState

    @MainActor
    init(
        emitter: DiagnosticsEmitter,
        measurement: GPUFrameDiagnostics,
        sessionStart: SuspendingClock.Instant,
        start: SuspendingClock.Instant,
        signpostState: OSSignpostIntervalState
    ) {
        self.emitter = emitter
        self.measurement = measurement
        self.sessionStart = sessionStart
        self.start = start
        self.signpostState = signpostState
    }

    /// Ends the cross-thread signpost immediately, then hops only retention to
    /// MainActor. The caller still controls error recording and slot release.
    nonisolated func complete(feedbackError: (any Error)?) {
        let completion = SuspendingClock().now
        DiagnosticsOSHandles.signposter(for: .renderGPU).endInterval(
            "GPUFrame",
            signpostState
        )
        let result: GPUFrameResult = feedbackError == nil ? .completed : .failed
        let errorType = feedbackError.map { String(reflecting: type(of: $0)) }
        let completedMeasurement = GPUFrameDiagnostics(
            submissionID: measurement.submissionID,
            frameSequence: measurement.frameSequence,
            sourceTick: measurement.sourceTick,
            frameSlot: measurement.frameSlot,
            result: result,
            errorType: errorType,
            durationNanoseconds: start.duration(to: completion).diagnosticsNanoseconds
        )
        let timestamp = DiagnosticsTimestamp(
            nanosecondsSinceSessionStart: sessionStart.duration(to: completion).diagnosticsNanoseconds
        )
        Task { @MainActor [weak emitter] in
            emitter?.recordCompletedGPUFrame(completedMeasurement, timestamp: timestamp)
        }
    }

    /// Closes an interval when health changed before queue commit.
    @MainActor
    func completeWithoutSubmission() {
        let completion = SuspendingClock().now
        DiagnosticsOSHandles.signposter(for: .renderGPU).endInterval(
            "GPUFrame",
            signpostState
        )
        emitter?.recordCompletedGPUFrame(
            GPUFrameDiagnostics(
                submissionID: measurement.submissionID,
                frameSequence: measurement.frameSequence,
                sourceTick: measurement.sourceTick,
                frameSlot: measurement.frameSlot,
                result: .notSubmitted,
                errorType: nil,
                durationNanoseconds: start.duration(to: completion).diagnosticsNanoseconds
            ),
            timestamp: DiagnosticsTimestamp(
                nanosecondsSinceSessionStart: sessionStart.duration(to: completion).diagnosticsNanoseconds
            )
        )
    }
}
