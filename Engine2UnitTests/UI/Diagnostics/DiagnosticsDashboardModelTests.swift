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

    @Test func scrubFractionClampsFiniteOutOfRangeValues() {
        let runtime = DiagnosticsRuntime(recentSampleCapacity: 8)
        recordStep(1, in: runtime)
        recordStep(2, in: runtime)
        recordStep(3, in: runtime)
        let model = DiagnosticsDashboardModel(controller: runtime)

        model.setScrubFraction(-100)
        #expect(model.scrubFraction == 0)
        #expect(model.presentation.cadence.isEmpty)

        model.setScrubFraction(100)
        #expect(model.scrubFraction == 1)
        #expect(model.presentation.cadence.count == 3)
    }

    @Test func pausedRefreshDoesNotPullNewSamplesUntilResumed() {
        let runtime = DiagnosticsRuntime(recentSampleCapacity: 8)
        recordStep(1, in: runtime)
        let model = DiagnosticsDashboardModel(controller: runtime)
        model.setScrubFraction(1)
        recordStep(2, in: runtime)

        model.refresh()
        #expect(model.presentation.cadence.count == 1)

        model.togglePaused()
        #expect(model.presentation.cadence.count == 2)
        #expect(model.scrubFraction == 1)
    }

    @Test func exportReturnsFullLatestSnapshotEvenWhilePresentationIsScrubbed() {
        let runtime = DiagnosticsRuntime(recentSampleCapacity: 8)
        recordStep(1, in: runtime)
        recordStep(2, in: runtime)
        recordStep(3, in: runtime)
        let model = DiagnosticsDashboardModel(controller: runtime)

        model.setScrubFraction(0)

        #expect(model.presentation.cadence.isEmpty)
        #expect(model.exportSnapshot().recentSamples.count == 3)
        #expect(model.exportSnapshot().totalSamplesReceived == 3)
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
