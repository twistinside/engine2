import Foundation
import Testing
@testable import Engine2

struct DiagnosticsEmitterTests {
    @MainActor
    @Test func stableNamesRemainUnique() {
        #expect(
            Set(DiagnosticsSignpostName.allCases.map(\.rawValue)).count
                == DiagnosticsSignpostName.allCases.count
        )
        #expect(
            Set(DiagnosticsLogEventName.allCases.map(\.rawValue)).count
                == DiagnosticsLogEventName.allCases.count
        )
        #expect(DiagnosticsOSHandles.subsystem == "com.example.Engine2")
    }

    @MainActor
    @Test func measurementForwardsExactTypedFacts() throws {
        let baseInstant = SuspendingClock().now
        let instants = [
            baseInstant,
            baseInstant.advanced(by: .milliseconds(1)),
            baseInstant.advanced(by: .milliseconds(6)),
            baseInstant.advanced(by: .milliseconds(8)),
            baseInstant.advanced(by: .milliseconds(15))
        ]
        var instantIndex = 0
        let sink = RecordingDiagnosticsSink()
        let emitter = DiagnosticsEmitter(
            sessionID: DiagnosticsSessionID(
                rawValue: try #require(
                    UUID(uuidString: "DFF69360-3B72-45B7-A353-10C0E5BC75A8")
                )
            ),
            sink: sink,
            timeSource: {
                defer { instantIndex += 1 }
                return instants[instantIndex]
            }
        )

        let stepResult = emitter.measureSimulationStep(
            tick: SimulationTick(rawValue: 3),
            didRunSimulationSystems: true
        ) {
            "step-result"
        }
        let systemResult = emitter.measureSystemUpdate(
            tick: SimulationTick(rawValue: 3),
            systemID: .movement,
            scheduleLane: .simulation,
            executionOrder: 1,
            workCount: 6
        ) {
            42
        }

        #expect(stepResult == "step-result")
        #expect(systemResult == 42)
        #expect(sink.samples.count == 2)
        #expect(sink.samples[0].timestamp.nanosecondsSinceSessionStart == 6_000_000)
        #expect(
            sink.samples[0].payload == .simulationStep(
                SimulationStepDiagnostics(
                    tick: SimulationTick(rawValue: 3),
                    didRunSimulationSystems: true,
                    durationNanoseconds: 5_000_000
                )
            )
        )
        #expect(sink.samples[1].timestamp.nanosecondsSinceSessionStart == 15_000_000)
        #expect(
            sink.samples[1].payload == .systemUpdate(
                SystemUpdateDiagnostics(
                    tick: SimulationTick(rawValue: 3),
                    systemID: .movement,
                    scheduleLane: .simulation,
                    executionOrder: 1,
                    durationNanoseconds: 7_000_000,
                    workCount: 6
                )
            )
        )
    }
}
