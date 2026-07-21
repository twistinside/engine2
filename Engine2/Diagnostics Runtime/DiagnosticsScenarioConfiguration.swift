import Foundation

/// Validated launch configuration for a deterministic diagnostics scenario.
///
/// The configuration is inert unless the scenario argument is present, which
/// keeps the ordinary interactive application lifecycle unchanged.
struct DiagnosticsScenarioConfiguration: Equatable, Sendable {
    static let scenarioArgument = "--diagnostics-scenario"

    let scenarioID: DiagnosticsScenarioID
    let randomSeed: UInt64
    let warmUpNanoseconds: UInt64
    let measurementNanoseconds: UInt64
    let writesNDJSONToStandardOutput: Bool

    init(
        scenarioID: DiagnosticsScenarioID = .baselineSixBall,
        randomSeed: UInt64 = 42,
        warmUpNanoseconds: UInt64 = 2_000_000_000,
        measurementNanoseconds: UInt64 = 15_000_000_000,
        writesNDJSONToStandardOutput: Bool = true
    ) {
        self.scenarioID = scenarioID
        self.randomSeed = randomSeed
        self.warmUpNanoseconds = warmUpNanoseconds
        self.measurementNanoseconds = measurementNanoseconds
        self.writesNDJSONToStandardOutput = writesNDJSONToStandardOutput
    }

    /// Parses the repository-owned launch vocabulary, returning `nil` for an
    /// ordinary interactive launch.
    static func parse(arguments: [String]) throws -> DiagnosticsScenarioConfiguration? {
        guard arguments.contains(scenarioArgument) else {
            return nil
        }

        var values: [String: String] = [:]
        var writesNDJSON = false
        var index = 1
        while index < arguments.count {
            let argument = arguments[index]
            if argument == "--diagnostics-ndjson-stdout" {
                writesNDJSON = true
                index += 1
                continue
            }

            guard argument.hasPrefix("--diagnostics-") else {
                index += 1
                continue
            }
            guard index + 1 < arguments.count else {
                throw DiagnosticsScenarioError.missingValue(argument)
            }
            values[argument] = arguments[index + 1]
            index += 2
        }

        guard let scenarioValue = values[scenarioArgument],
              let scenarioID = DiagnosticsScenarioID(rawValue: scenarioValue) else {
            throw DiagnosticsScenarioError.invalidScenario(values[scenarioArgument] ?? "")
        }

        return DiagnosticsScenarioConfiguration(
            scenarioID: scenarioID,
            randomSeed: try parseUInt64(values["--diagnostics-seed"] ?? "42", name: "seed"),
            warmUpNanoseconds: try parseUInt64(
                values["--diagnostics-warm-up-nanoseconds"] ?? "2000000000",
                name: "warm-up-nanoseconds"
            ),
            measurementNanoseconds: try parsePositiveUInt64(
                values["--diagnostics-measurement-nanoseconds"] ?? "15000000000",
                name: "measurement-nanoseconds"
            ),
            writesNDJSONToStandardOutput: writesNDJSON
        )
    }

    private static func parseUInt64(_ value: String, name: String) throws -> UInt64 {
        guard let parsed = UInt64(value) else {
            throw DiagnosticsScenarioError.invalidUnsignedInteger(name: name, value: value)
        }
        return parsed
    }

    private static func parsePositiveUInt64(_ value: String, name: String) throws -> UInt64 {
        let parsed = try parseUInt64(value, name: name)
        guard parsed > 0 else {
            throw DiagnosticsScenarioError.nonPositiveValue(name)
        }
        return parsed
    }
}
