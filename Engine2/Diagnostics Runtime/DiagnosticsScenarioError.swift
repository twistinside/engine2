/// Explicit scenario launch failures suitable for command-line diagnostics.
enum DiagnosticsScenarioError: Error, Equatable, CustomStringConvertible {
    case invalidScenario(String)
    case invalidUnsignedInteger(name: String, value: String)
    case missingValue(String)
    case nonPositiveValue(String)
    case standardOutputRequired
    case tickCountExceedsProcessLimit(UInt64)

    var description: String {
        switch self {
        case let .invalidScenario(value):
            "Unknown diagnostics scenario: \(value)"
        case let .invalidUnsignedInteger(name, value):
            "Invalid unsigned integer for \(name): \(value)"
        case let .missingValue(argument):
            "Missing value after \(argument)"
        case let .nonPositiveValue(name):
            "\(name) must be greater than zero"
        case .standardOutputRequired:
            "The baseline scenario requires --diagnostics-ndjson-stdout"
        case let .tickCountExceedsProcessLimit(count):
            "Scenario tick count exceeds this process limit: \(count)"
        }
    }
}
