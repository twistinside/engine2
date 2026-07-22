import Testing
@testable import Engine2

@MainActor
struct DiagnosticsScenarioTests {
    @Test func launchArgumentsAreExplicitAndInteractiveLaunchIsUnaffected() throws {
        #expect(try DiagnosticsScenarioConfiguration.parse(arguments: ["Engine2"]) == nil)
        #expect(
            try DiagnosticsScenarioConfiguration.parse(arguments: [
                "Engine2",
                "--diagnostics-scenario", "baseline-six-ball",
                "--diagnostics-seed", "7",
                "--diagnostics-warm-up-nanoseconds", "10",
                "--diagnostics-measurement-nanoseconds", "20",
                "--diagnostics-ndjson-stdout"
            ]) == DiagnosticsScenarioConfiguration(
                randomSeed: 7,
                warmUpNanoseconds: 10,
                measurementNanoseconds: 20
            )
        )
    }

    @Test func baselineScenarioHasRepeatableStructureAcrossRuns() throws {
        let first = try runScenario()
        let second = try runScenario()

        #expect(first.manifest.scenarioID == .baselineSixBall)
        #expect(first.manifest.randomSeed == second.manifest.randomSeed)
        #expect(first.manifest.fixedStepNanoseconds == second.manifest.fixedStepNanoseconds)
        #expect(kindCounts(first.samples) == kindCounts(second.samples))
        #expect(completedTicks(first.samples) == completedTicks(second.samples))
        #expect(inventories(first.samples) == inventories(second.samples))
    }

    private func runScenario() throws -> DiagnosticsScenarioRunResult {
        let runtime = DiagnosticsRuntime(recentSampleCapacity: 1_024)
        let emitter = DiagnosticsEmitter(sessionID: runtime.sessionID, sink: runtime)
        let simulation = SimulationRuntime(diagnostics: emitter)
        return try DiagnosticsScenarioRunner(
            configuration: DiagnosticsScenarioConfiguration(
                warmUpNanoseconds: 32_000_000,
                measurementNanoseconds: 64_000_000
            )
        ).run(
            simulation: simulation,
            diagnosticsRuntime: runtime,
            diagnostics: emitter
        )
    }

    private func kindCounts(_ samples: [DiagnosticsSample]) -> [DiagnosticsSampleKind: Int] {
        samples.reduce(into: [:]) { counts, sample in
            counts[sample.payload.kind, default: 0] += 1
        }
    }

    private func completedTicks(_ samples: [DiagnosticsSample]) -> [SimulationTick] {
        samples.compactMap { sample in
            guard case let .simulationStep(payload) = sample.payload else {
                return nil
            }
            return payload.tick
        }
    }

    private func inventories(_ samples: [DiagnosticsSample]) -> [SimulationRuntimeInventoryDiagnostics] {
        samples.compactMap { sample in
            guard case let .simulationRuntimeInventory(payload) = sample.payload else {
                return nil
            }
            return payload
        }
    }
}
