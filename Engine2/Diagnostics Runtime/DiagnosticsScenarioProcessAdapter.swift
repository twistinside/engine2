import Darwin
import Foundation

/// Isolates command-line output and termination from scenario execution.
@MainActor
enum DiagnosticsScenarioProcessAdapter {
    static func runIfRequested(
        arguments: [String],
        simulation: SimulationRuntime,
        diagnosticsRuntime: DiagnosticsRuntime,
        diagnostics: DiagnosticsEmitter
    ) {
        do {
            guard let configuration = try DiagnosticsScenarioConfiguration.parse(arguments: arguments) else {
                return
            }
            guard configuration.writesNDJSONToStandardOutput else {
                throw DiagnosticsScenarioError.standardOutputRequired
            }

            let result = try DiagnosticsScenarioRunner(configuration: configuration).run(
                simulation: simulation,
                diagnosticsRuntime: diagnosticsRuntime,
                diagnostics: diagnostics
            )
            let encoder = DiagnosticsNDJSONEncoder()
            try encoder.write(.manifest(result.manifest), to: FileHandle.standardOutput.write)
            for sample in result.samples {
                try encoder.write(.sample(sample), to: FileHandle.standardOutput.write)
            }
            exit(EXIT_SUCCESS)
        } catch {
            let message = "diagnostics scenario failed: \(error)\n"
            FileHandle.standardError.write(Data(message.utf8))
            exit(EX_USAGE)
        }
    }
}
