/// Failure while validating or executing one recorded Simulation replay.
///
/// Persistence decoding translates invalid encoded values into `DecodingError`.
/// Programmatic construction and replay execution preserve the corresponding
/// domain failure through this closed error vocabulary.
nonisolated enum SimulationReplayError: Error, Equatable, Sendable {
    case advanceRejected(SimulationAdvanceRejection)
    case advanceResultMismatch(
        expectedInitialCursor: SimulationCursor,
        result: SimulationAdvanceResult
    )
    case contentIdentifierMismatch(
        expected: RecordingContentIdentifier,
        recorded: RecordingContentIdentifier
    )
    case duplicateKeyboardKeys
    case duplicateMouseButtons
    case inputEntryAfterTerminalTick(
        entryTick: SimulationTick,
        terminalTick: SimulationTick
    )
    case inputEntryTickIsZero
    case inputEntryTicksNotStrictlyIncreasing(
        previous: SimulationTick,
        current: SimulationTick
    )
    case noneInputAssignmentRequiresGap
    case nonfiniteInputVector
}

extension SimulationReplayError: CustomStringConvertible {
    var description: String {
        switch self {
        case let .advanceRejected(rejection):
            "Simulation rejected recorded replay advancement: \(rejection)."

        case let .advanceResultMismatch(expectedInitialCursor, result):
            "A recorded replay request starting at \(expectedInitialCursor) "
                + "received a mismatched result from \(result.initialCursor) to \(result.finalCursor)."

        case let .contentIdentifierMismatch(expected, recorded):
            "The replay records content \(recorded.rawValue), but the host supplied \(expected.rawValue)."

        case .duplicateKeyboardKeys:
            "A recorded Input snapshot cannot contain duplicate keyboard keys."

        case .duplicateMouseButtons:
            "A recorded Input snapshot cannot contain duplicate mouse buttons."

        case let .inputEntryAfterTerminalTick(entryTick, terminalTick):
            "Input entry tick \(entryTick.rawValue) is after terminal tick \(terminalTick.rawValue)."

        case .inputEntryTickIsZero:
            "A recorded Input assignment must be consumed while producing a tick after tick zero."

        case let .inputEntryTicksNotStrictlyIncreasing(previous, current):
            "Input entry tick \(current.rawValue) must be greater than preceding tick \(previous.rawValue)."

        case .noneInputAssignmentRequiresGap:
            "A replay represents a .none Input assignment with a gap, not an explicit entry."

        case .nonfiniteInputVector:
            "Recorded Input coordinates and cumulative totals must be finite."
        }
    }
}
