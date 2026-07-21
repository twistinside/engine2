/// Executes repository-owned deterministic workloads without owning process IO.
@MainActor
struct DiagnosticsScenarioRunner {
    let configuration: DiagnosticsScenarioConfiguration

    /// Runs warm-up outside retained evidence, then records a clean measurement
    /// window through the same Simulation Runtime boundary used by the app.
    func run(
        simulation: SimulationRuntime,
        diagnosticsRuntime: DiagnosticsRuntime,
        diagnostics: DiagnosticsEmitter
    ) throws -> DiagnosticsScenarioRunResult {
        let fixedStepNanoseconds = simulation.state.fixedTimeStep.diagnosticsNanoseconds
        let warmUpTicks = try tickCount(
            covering: configuration.warmUpNanoseconds,
            fixedStepNanoseconds: fixedStepNanoseconds
        )
        let measurementTicks = try tickCount(
            covering: configuration.measurementNanoseconds,
            fixedStepNanoseconds: fixedStepNanoseconds
        )

        simulation.runDiagnosticFixedSteps(count: warmUpTicks) { snapshot in
            _ = diagnostics.measureRenderProjection(from: snapshot)
        }
        diagnosticsRuntime.reset()
        simulation.reportDiagnosticInventory()
        simulation.runDiagnosticFixedSteps(count: measurementTicks) { snapshot in
            _ = diagnostics.measureRenderProjection(from: snapshot)
        }

        let manifest = DiagnosticsManifest(
            sessionID: diagnosticsRuntime.sessionID,
            scenarioID: configuration.scenarioID,
            buildConfiguration: Self.buildConfiguration,
            randomSeed: configuration.randomSeed,
            fixedStepNanoseconds: fixedStepNanoseconds,
            warmUpNanoseconds: configuration.warmUpNanoseconds,
            measurementNanoseconds: configuration.measurementNanoseconds
        )
        return DiagnosticsScenarioRunResult(
            manifest: manifest,
            samples: diagnosticsRuntime.latestDiagnosticsSnapshot.recentSamples
        )
    }

    private func tickCount(
        covering nanoseconds: UInt64,
        fixedStepNanoseconds: UInt64
    ) throws -> Int {
        guard fixedStepNanoseconds > 0 else {
            throw DiagnosticsScenarioError.nonPositiveValue("fixed-step-nanoseconds")
        }
        let quotient = nanoseconds / fixedStepNanoseconds
        let remainder = nanoseconds % fixedStepNanoseconds
        let count = quotient + (remainder == 0 ? 0 : 1)
        guard count <= UInt64(Int.max) else {
            throw DiagnosticsScenarioError.tickCountExceedsProcessLimit(count)
        }
        return Int(count)
    }

    private static var buildConfiguration: DiagnosticsBuildConfiguration {
#if DEBUG
        .debug
#else
        .release
#endif
    }
}
