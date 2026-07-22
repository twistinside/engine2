import Testing
@testable import Engine2

struct DiagnosticsHUDPresentationTests {
    @Test func derivesHealthWithoutReadingLiveRuntimeState() {
        let sessionID = DiagnosticsSessionID()
        let samples = [
            sample(sessionID, .simulationStep(SimulationStepDiagnostics(
                tick: SimulationTick(rawValue: 12),
                didRunSimulationSystems: true,
                durationNanoseconds: 100
            ))),
            sample(sessionID, .systemUpdate(SystemUpdateDiagnostics(
                tick: SimulationTick(rawValue: 12),
                systemID: .movement,
                scheduleLane: .simulation,
                executionOrder: 1,
                durationNanoseconds: 20,
                workCount: 6
            ))),
            sample(sessionID, .renderFrameCPU(RenderFrameCPUDiagnostics(
                frameSequence: RenderFrameSequence(rawValue: 4),
                sourceTick: SimulationTick(rawValue: 10),
                didSourceTickChange: true,
                submittedInstanceCount: 6,
                renderPassCount: 2,
                drawCount: 6,
                submeshCount: 6,
                wasTruncated: false,
                result: .submitted,
                durationNanoseconds: 300
            )))
        ]
        let snapshot = DiagnosticsSnapshot(
            sessionID: sessionID,
            isCollectionEnabled: true,
            recentSampleCapacity: 32,
            totalSamplesReceived: samples.count,
            recentSamples: samples,
            aggregates: [
                DiagnosticsSampleAggregate(
                    kind: .renderFrameCPU,
                    sampleCount: 2,
                    durationSampleCount: 2,
                    totalDurationNanoseconds: 500,
                    minimumDurationNanoseconds: 200,
                    maximumDurationNanoseconds: 300
                )
            ]
        )

        let presentation = DiagnosticsHUDPresentation(snapshot: snapshot)

        #expect(presentation.simulationTick == 12)
        #expect(presentation.renderFreshnessTicks == 2)
        #expect(presentation.inFlightFrameCount == 1)
        #expect(presentation.averageRenderCPUNanoseconds == 250)
        #expect(presentation.maximumRenderCPUNanoseconds == 300)
        #expect(presentation.latestSystemWorkCount == 6)
    }

    private func sample(
        _ sessionID: DiagnosticsSessionID,
        _ payload: DiagnosticsSamplePayload
    ) -> DiagnosticsSample {
        DiagnosticsSample(
            sessionID: sessionID,
            timestamp: .zero,
            category: .diagnosticsCapture,
            payload: payload
        )
    }
}
