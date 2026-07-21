/// Stable, low-cardinality ownership categories shared by traces and samples.
enum DiagnosticsCategory: String, Codable, CaseIterable, Sendable {
    case appLifecycle = "app.lifecycle"
    case inputRuntime = "input.runtime"
    case simulationLoop = "simulation.loop"
    case simulationSystem = "simulation.system"
    case simulationSnapshot = "simulation.snapshot"
    case renderFrame = "render.frame"
    case renderAsset = "render.asset"
    case renderGPU = "render.gpu"
    case diagnosticsCapture = "diagnostics.capture"
}
