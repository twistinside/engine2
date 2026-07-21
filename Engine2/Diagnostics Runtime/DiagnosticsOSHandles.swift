import OSLog

/// Centralized immutable handles for Engine2 unified logs and signposts.
enum DiagnosticsOSHandles {
    static let subsystem = "com.example.Engine2"

    static func logger(for category: DiagnosticsCategory) -> Logger {
        switch category {
        case .appLifecycle: appLifecycleLogger
        case .inputRuntime: inputRuntimeLogger
        case .simulationLoop: simulationLoopLogger
        case .simulationSystem: simulationSystemLogger
        case .simulationSnapshot: simulationSnapshotLogger
        case .renderFrame: renderFrameLogger
        case .renderAsset: renderAssetLogger
        case .renderGPU: renderGPULogger
        case .diagnosticsCapture: diagnosticsCaptureLogger
        }
    }

    static func signposter(for category: DiagnosticsCategory) -> OSSignposter {
        switch category {
        case .appLifecycle: appLifecycleSignposter
        case .inputRuntime: inputRuntimeSignposter
        case .simulationLoop: simulationLoopSignposter
        case .simulationSystem: simulationSystemSignposter
        case .simulationSnapshot: simulationSnapshotSignposter
        case .renderFrame: renderFrameSignposter
        case .renderAsset: renderAssetSignposter
        case .renderGPU: renderGPUSignposter
        case .diagnosticsCapture: diagnosticsCaptureSignposter
        }
    }

    private static let appLifecycleLogger = Logger(subsystem: subsystem, category: DiagnosticsCategory.appLifecycle.rawValue)
    private static let inputRuntimeLogger = Logger(subsystem: subsystem, category: DiagnosticsCategory.inputRuntime.rawValue)
    private static let simulationLoopLogger = Logger(subsystem: subsystem, category: DiagnosticsCategory.simulationLoop.rawValue)
    private static let simulationSystemLogger = Logger(subsystem: subsystem, category: DiagnosticsCategory.simulationSystem.rawValue)
    private static let simulationSnapshotLogger = Logger(subsystem: subsystem, category: DiagnosticsCategory.simulationSnapshot.rawValue)
    private static let renderFrameLogger = Logger(subsystem: subsystem, category: DiagnosticsCategory.renderFrame.rawValue)
    private static let renderAssetLogger = Logger(subsystem: subsystem, category: DiagnosticsCategory.renderAsset.rawValue)
    private static let renderGPULogger = Logger(subsystem: subsystem, category: DiagnosticsCategory.renderGPU.rawValue)
    private static let diagnosticsCaptureLogger = Logger(subsystem: subsystem, category: DiagnosticsCategory.diagnosticsCapture.rawValue)

    private static let appLifecycleSignposter = OSSignposter(logger: appLifecycleLogger)
    private static let inputRuntimeSignposter = OSSignposter(logger: inputRuntimeLogger)
    private static let simulationLoopSignposter = OSSignposter(logger: simulationLoopLogger)
    private static let simulationSystemSignposter = OSSignposter(logger: simulationSystemLogger)
    private static let simulationSnapshotSignposter = OSSignposter(logger: simulationSnapshotLogger)
    private static let renderFrameSignposter = OSSignposter(logger: renderFrameLogger)
    private static let renderAssetSignposter = OSSignposter(logger: renderAssetLogger)
    private static let renderGPUSignposter = OSSignposter(logger: renderGPULogger)
    private static let diagnosticsCaptureSignposter = OSSignposter(logger: diagnosticsCaptureLogger)
}
