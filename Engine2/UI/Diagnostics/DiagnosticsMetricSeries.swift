/// Closed chart series used by the expanded diagnostics dashboard.
enum DiagnosticsMetricSeries: String, CaseIterable, Sendable {
    case simulationStep = "Simulation step"
    case presentationSnapshot = "Snapshot capture"
    case renderProjection = "Render projection"
    case frameSlotWait = "Frame-slot wait"
    case frameEncode = "Frame encode"
    case renderFrameCPU = "Render CPU"
    case gpuFrame = "GPU frame"
    case backlog = "Backlog"
    case freshness = "Freshness"
    case system = "System"
}
