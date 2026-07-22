import Foundation
import Testing
@testable import Engine2

struct DiagnosticsBoundaryTests {
    @Test func timestampsHaveAStableOrdering() {
        let earlier = DiagnosticsTimestamp(nanosecondsSinceSessionStart: 10)
        let later = DiagnosticsTimestamp(nanosecondsSinceSessionStart: 20)

        #expect(earlier < later)
        #expect(DiagnosticsTimestamp.zero < later)
    }

    @Test func simulationPayloadRoundTripsThroughCodable() throws {
        let sessionID = DiagnosticsSessionID(
            rawValue: try #require(UUID(uuidString: "67F04A60-2ED6-48AF-9103-C03360463AE7"))
        )
        let sample = DiagnosticsSample(
            sessionID: sessionID,
            timestamp: DiagnosticsTimestamp(nanosecondsSinceSessionStart: 42),
            category: .simulationSystem,
            payload: .systemUpdate(
                SystemUpdateDiagnostics(
                    tick: SimulationTick(rawValue: 7),
                    systemID: .movement,
                    scheduleLane: .simulation,
                    executionOrder: 1,
                    durationNanoseconds: 900,
                    workCount: 6
                )
            )
        )

        let encoded = try JSONEncoder().encode(sample)
        let decoded = try JSONDecoder().decode(DiagnosticsSample.self, from: encoded)

        #expect(decoded == sample)
    }

    @Test func categoryVocabularyIsStableAndUnique() {
        let rawValues = DiagnosticsCategory.allCases.map(\.rawValue)

        #expect(Set(rawValues).count == DiagnosticsCategory.allCases.count)
        #expect(DiagnosticsCategory.simulationLoop.rawValue == "simulation.loop")
        #expect(DiagnosticsCategory.renderGPU.rawValue == "render.gpu")
    }

    @MainActor
    @Test func noOpSinkAcceptsSamplesWithoutRetainingState() throws {
        let sink = NoOpDiagnosticsSink()
        let sample = DiagnosticsSample(
            sessionID: DiagnosticsSessionID(
                rawValue: try #require(
                    UUID(uuidString: "04B61198-6FC2-42AF-8AC2-2AFA66F0EA3A")
                )
            ),
            timestamp: .zero,
            category: .simulationLoop,
            payload: .simulationStep(
                SimulationStepDiagnostics(
                    tick: .zero,
                    didRunSimulationSystems: false,
                    durationNanoseconds: 0
                )
            )
        )

        sink.record(sample)
    }
}
