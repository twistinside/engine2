import Testing
@testable import Engine2

struct DiagnosticsDashboardPresentationTests {
    @Test func emptySnapshotProducesEmptyChartsAndStableFunnel() {
        let presentation = DiagnosticsDashboardPresentation(snapshot: snapshot([]))
        #expect(presentation.cadence.isEmpty)
        #expect(presentation.backlog.isEmpty)
        #expect(presentation.errors.isEmpty)
        #expect(presentation.presentationFunnel.map(\.count) == [0, 0, 0, 0])
    }

    @Test func healthySamplesPopulateCadenceFunnelPhasesAndResources() {
        let samples = [
            sample(.simulationStep(SimulationStepDiagnostics(
                tick: SimulationTick(rawValue: 10),
                didRunSimulationSystems: true,
                durationNanoseconds: 100
            ))),
            sample(.renderProjection(RenderProjectionDiagnostics(
                sourceTick: SimulationTick(rawValue: 10),
                publishedPresentationCount: 6,
                acceptedInstanceCount: 5,
                rejectedPresentationCount: 1,
                durationNanoseconds: 30
            ))),
            sample(.renderFrameCPU(RenderFrameCPUDiagnostics(
                frameSequence: RenderFrameSequence(rawValue: 2),
                sourceTick: SimulationTick(rawValue: 9),
                didSourceTickChange: true,
                submittedInstanceCount: 5,
                renderPassCount: 2,
                drawCount: 5,
                submeshCount: 5,
                wasTruncated: false,
                result: .submitted,
                durationNanoseconds: 200
            ))),
            sample(.renderResourceInventory(RenderResourceInventoryDiagnostics(
                modelCount: 1,
                meshCount: 1,
                submeshCount: 1,
                pipelineCount: 4,
                argumentTableCount: 3,
                materialCount: 6,
                frameResourceCount: 3
            )))
        ]
        let presentation = DiagnosticsDashboardPresentation(snapshot: snapshot(samples))
        #expect(presentation.cadence.count == 3)
        #expect(presentation.freshness.map(\.value) == [1])
        #expect(presentation.presentationFunnel.map(\.count) == [6, 5, 1, 5])
        #expect(presentation.resources.contains { $0.name == "pipelines" && $0.count == 4 })
    }

    @Test func backlogAndRenderErrorRemainExplicit() {
        let samples = [
            sample(.simulationPoll(SimulationPollDiagnostics(
                completedTick: SimulationTick(rawValue: 2),
                sampledWallDeltaNanoseconds: 20,
                stepsCompleted: 1,
                backlogBeforeNanoseconds: 12,
                backlogAfterNanoseconds: 4,
                durationNanoseconds: 3
            ))),
            sample(.renderResourceFailure(RenderResourceFailureDiagnostics(
                stage: .models,
                errorType: "FixtureError"
            )))
        ]
        let presentation = DiagnosticsDashboardPresentation(snapshot: snapshot(samples))
        #expect(presentation.backlog.map(\.value) == [4])
        #expect(presentation.errors.map(\.source) == ["models"])
    }

    private func snapshot(_ samples: [DiagnosticsSample]) -> DiagnosticsSnapshot {
        DiagnosticsSnapshot(
            sessionID: DiagnosticsSessionID(),
            isCollectionEnabled: true,
            recentSampleCapacity: 64,
            totalSamplesReceived: samples.count,
            recentSamples: samples,
            aggregates: []
        )
    }

    private func sample(_ payload: DiagnosticsSamplePayload) -> DiagnosticsSample {
        DiagnosticsSample(
            sessionID: DiagnosticsSessionID(),
            timestamp: .zero,
            category: .diagnosticsCapture,
            payload: payload
        )
    }
}
