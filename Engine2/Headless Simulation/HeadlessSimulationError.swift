/// Failure that prevents the headless executable from producing a valid result.
enum HeadlessSimulationError: Error {
    case advanceRejected(SimulationAdvanceRejection)
    case entityCountMismatch(
        store: HeadlessSimulationEntityStore,
        expected: Int,
        actual: Int
    )
    case invalidConfiguration(String)
    case invalidEnvironmentValue(
        key: HeadlessSimulationEnvironmentKey,
        value: String
    )
    case invariantViolation(String)
}

extension HeadlessSimulationError: CustomStringConvertible {
    var description: String {
        switch self {
        case let .advanceRejected(rejection):
            "Simulation rejected a headless tick: \(rejection)"
        case let .entityCountMismatch(store, expected, actual):
            "The \(store.rawValue) store contains \(actual) entities; expected \(expected)."
        case let .invalidConfiguration(message):
            message
        case let .invalidEnvironmentValue(key, value):
            "\(key.rawValue) must contain a positive integer; received \(value)."
        case let .invariantViolation(message):
            message
        }
    }
}
