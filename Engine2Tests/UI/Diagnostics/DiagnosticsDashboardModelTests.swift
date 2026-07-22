import Testing
@testable import Engine2

@MainActor
struct DiagnosticsDashboardModelTests {
    @Test func pauseScrubCaptureAndResetHaveDistinctStateTransitions() {
        let runtime = DiagnosticsRuntime(recentSampleCapacity: 8)
        recordStep(1, in: runtime)
        recordStep(2, in: runtime)
        let model = DiagnosticsDashboardModel(controller: runtime)

        #expect(model.presentation.cadence.count == 2)
        model.setScrubFraction(0.5)
        #expect(model.isPaused)
        #expect(model.presentation.cadence.count == 1)

        model.togglePaused()
        #expect(!model.isPaused)
        #expect(model.presentation.cadence.count == 2)

        model.stopCaptureSession()
        #expect(!runtime.latestDiagnosticsSnapshot.isCollectionEnabled)
        model.startCaptureSession()
        #expect(runtime.latestDiagnosticsSnapshot.isCollectionEnabled)
        #expect(runtime.latestDiagnosticsSnapshot.totalSamplesReceived == 0)

        recordStep(3, in: runtime)
        model.refresh()
        #expect(model.presentation.cadence.count == 1)
        model.reset()
        #expect(model.presentation.cadence.isEmpty)
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
