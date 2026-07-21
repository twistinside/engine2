/// Stable semantic event names written to unified logging.
enum DiagnosticsLogEventName: String, CaseIterable, Sendable {
    case simulationLoopStarted = "simulation_loop_started"
    case simulationLoopStopped = "simulation_loop_stopped"
    case simulationLoopCancelled = "simulation_loop_cancelled"
    case simulationBacklogHigh = "simulation_backlog_high"
    case renderPreparationFailed = "render_preparation_failed"
    case renderSubmissionFailed = "render_submission_failed"
    case diagnosticsCaptureStarted = "diagnostics_capture_started"
    case diagnosticsCaptureCompleted = "diagnostics_capture_completed"
    case diagnosticsCaptureFailed = "diagnostics_capture_failed"
}
