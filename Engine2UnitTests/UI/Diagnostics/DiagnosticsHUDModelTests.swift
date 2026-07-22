import Testing
@testable import Engine2

@MainActor
struct DiagnosticsHUDModelTests {
    @Test func initializerSamplesCurrentSourceValueImmediately() {
        let runtime = DiagnosticsRuntime(recentSampleCapacity: 4)
        recordStep(3, in: runtime)

        let model = DiagnosticsHUDModel(source: runtime)

        #expect(model.presentation.simulationTick == 3)
        #expect(model.presentation.isCollectionEnabled)
    }

    @Test func refreshPullsANewerImmutableSnapshot() {
        let runtime = DiagnosticsRuntime(recentSampleCapacity: 4)
        let model = DiagnosticsHUDModel(source: runtime)
        recordStep(4, in: runtime)

        #expect(model.presentation.simulationTick == nil)

        model.refresh()

        #expect(model.presentation.simulationTick == 4)
    }

    @Test func modelDoesNotExtendSourceLifetimeAndKeepsLastPresentation() {
        var runtime: DiagnosticsRuntime? = DiagnosticsRuntime(recentSampleCapacity: 4)
        recordStep(5, in: runtime!)
        weak var weakRuntime = runtime
        let model = DiagnosticsHUDModel(source: runtime!)
        let lastPresentation = model.presentation

        runtime = nil
        model.refresh()

        #expect(weakRuntime == nil)
        #expect(model.presentation == lastPresentation)
    }

    private func recordStep(_ tick: UInt64, in runtime: DiagnosticsRuntime) {
        runtime.record(
            DiagnosticsSample(
                sessionID: runtime.sessionID,
                timestamp: DiagnosticsTimestamp(nanosecondsSinceSessionStart: tick),
                category: .simulationLoop,
                payload: .simulationStep(
                    SimulationStepDiagnostics(
                        tick: SimulationTick(rawValue: tick),
                        didRunSimulationSystems: true,
                        durationNanoseconds: 1
                    )
                )
            )
        )
    }
}
