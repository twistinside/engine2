import Foundation
import Testing
@testable import Engine2

struct DiagnosticsRuntimeTests {
    @MainActor
    @Test func boundedRingEvictsOldestSamplesAndKeepsAggregates() throws {
        let sessionID = DiagnosticsSessionID(
            rawValue: try #require(
                UUID(uuidString: "3B48C541-1438-4930-89EF-A1E91FA47767")
            )
        )
        let runtime = DiagnosticsRuntime(
            sessionID: sessionID,
            recentSampleCapacity: 3
        )

        for tick in 1...5 {
            runtime.record(stepSample(sessionID: sessionID, tick: UInt64(tick)))
        }

        let snapshot = runtime.latestDiagnosticsSnapshot
        #expect(snapshot.totalSamplesReceived == 5)
        #expect(snapshot.recentSamples.count == 3)
        #expect(snapshot.recentSamples.compactMap(stepTick) == [3, 4, 5])
        let aggregate = try #require(
            snapshot.aggregates.first(where: { $0.kind == .simulationStep })
        )
        #expect(aggregate.sampleCount == 5)
        #expect(aggregate.durationSampleCount == 5)
        #expect(aggregate.totalDurationNanoseconds == 15)
        #expect(aggregate.minimumDurationNanoseconds == 1)
        #expect(aggregate.maximumDurationNanoseconds == 5)
    }

    @MainActor
    @Test func disabledCollectionAndResetHaveExplicitSemantics() {
        let sessionID = DiagnosticsSessionID()
        let runtime = DiagnosticsRuntime(
            sessionID: sessionID,
            recentSampleCapacity: 2,
            isCollectionEnabled: false
        )
        runtime.record(stepSample(sessionID: sessionID, tick: 1))
        #expect(runtime.latestDiagnosticsSnapshot.totalSamplesReceived == 0)

        runtime.setCollectionEnabled(true)
        runtime.record(stepSample(sessionID: sessionID, tick: 2))
        #expect(runtime.latestDiagnosticsSnapshot.totalSamplesReceived == 1)

        runtime.reset()
        let snapshot = runtime.latestDiagnosticsSnapshot
        #expect(snapshot.sessionID == sessionID)
        #expect(snapshot.totalSamplesReceived == 0)
        #expect(snapshot.recentSamples.isEmpty)
        #expect(snapshot.aggregates.isEmpty)
    }

    @MainActor
    @Test func emitterDoesNotExtendDiagnosticsRuntimeLifetime() {
        var runtime: DiagnosticsRuntime? = DiagnosticsRuntime()
        weak let weakRuntime = runtime
        let emitter = DiagnosticsEmitter(
            sessionID: runtime?.sessionID ?? DiagnosticsSessionID(),
            sink: runtime ?? NoOpDiagnosticsSink()
        )

        runtime = nil

        #expect(weakRuntime == nil)
        _ = emitter
    }

    @MainActor
    @Test func samplesFromAnotherSessionAreIgnoredCompletely() {
        let runtime = DiagnosticsRuntime(recentSampleCapacity: 2)
        let foreignSession = DiagnosticsSessionID()

        runtime.record(stepSample(sessionID: foreignSession, tick: 1))

        #expect(runtime.totalSamplesReceived == 0)
        #expect(runtime.latestDiagnosticsSnapshot.recentSamples.isEmpty)
        #expect(runtime.latestDiagnosticsSnapshot.aggregates.isEmpty)
    }

    @MainActor
    @Test func publishedSnapshotsRemainDetachedAfterResetAndFurtherRecording() {
        let runtime = DiagnosticsRuntime(recentSampleCapacity: 2)
        runtime.record(stepSample(sessionID: runtime.sessionID, tick: 1))
        let beforeReset = runtime.latestDiagnosticsSnapshot

        runtime.reset()
        runtime.record(stepSample(sessionID: runtime.sessionID, tick: 2))
        let afterReset = runtime.latestDiagnosticsSnapshot

        #expect(beforeReset.totalSamplesReceived == 1)
        #expect(beforeReset.recentSamples.compactMap(stepTick) == [1])
        #expect(afterReset.totalSamplesReceived == 1)
        #expect(afterReset.recentSamples.compactMap(stepTick) == [2])
    }
}

@MainActor
private func stepSample(
    sessionID: DiagnosticsSessionID,
    tick: UInt64
) -> DiagnosticsSample {
    DiagnosticsSample(
        sessionID: sessionID,
        timestamp: DiagnosticsTimestamp(nanosecondsSinceSessionStart: tick),
        category: .simulationLoop,
        payload: .simulationStep(
            SimulationStepDiagnostics(
                tick: SimulationTick(rawValue: tick),
                didRunSimulationSystems: true,
                durationNanoseconds: tick
            )
        )
    )
}

@MainActor
private func stepTick(from sample: DiagnosticsSample) -> UInt64? {
    guard case let .simulationStep(payload) = sample.payload else {
        return nil
    }
    return payload.tick.rawValue
}
