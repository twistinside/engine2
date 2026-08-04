/// Finite advance authority that reconstructs one recorded Simulation timeline.
///
/// The driver validates content compatibility before constructing a fresh
/// `SimulationRuntime`. It then submits one exact cursor-qualified request per
/// completed tick and retains every returned presentation in order.
struct SimulationReplayDriver {
    let file: SimulationReplayFile
    let expectedContentIdentifier: RecordingContentIdentifier
    let worldBuilder: any PWorldBuilder
    let configuration: SimulationConfiguration

    func run() async throws(SimulationReplayError) -> SimulationReplayResult {
        guard file.contentIdentifier == expectedContentIdentifier else {
            throw .contentIdentifierMismatch(
                expected: expectedContentIdentifier,
                recorded: file.contentIdentifier
            )
        }

        let simulationRuntime = SimulationRuntime(
            worldBuilder: worldBuilder,
            configuration: configuration,
            inputBaseline: file.initialInputBaseline?.inputSnapshot
        )
        var presentationSnapshots: [SimulationPresentationSnapshot] = [
            simulationRuntime.latestPresentationSnapshot
        ]
        var currentCursor = simulationRuntime.currentCursor
        var entryIndex = 0

        while currentCursor.tick < file.terminalTick {
            let consumingTick = currentCursor.tick.advanced()
            let inputAssignment: SimulationInputAssignment

            if entryIndex < file.entries.count,
               file.entries[entryIndex].tick == consumingTick {
                inputAssignment = file.entries[entryIndex]
                    .inputAssignment
                    .inputAssignment
                entryIndex += 1
            } else {
                inputAssignment = .none
            }

            let result = try await advanceOneTick(
                simulationRuntime,
                expectedCursor: currentCursor,
                inputAssignment: inputAssignment
            )
            currentCursor = result.finalCursor
            presentationSnapshots.append(
                result.finalPresentationSnapshot
            )
        }

        return SimulationReplayResult(
            recordingID: file.recordingID,
            contentIdentifier: file.contentIdentifier,
            originalSessionID: file.originalSessionID,
            presentationSnapshots: presentationSnapshots
        )
    }

    private func advanceOneTick(
        _ simulationRuntime: SimulationRuntime,
        expectedCursor: SimulationCursor,
        inputAssignment: SimulationInputAssignment
    ) async throws(SimulationReplayError) -> SimulationAdvanceResult {
        let outcome = await simulationRuntime.advance(
            SimulationAdvanceRequest(
                expectedCursor: expectedCursor,
                stepCount: .one,
                inputAssignment: inputAssignment
            )
        )
        let result: SimulationAdvanceResult

        switch outcome {
        case let .completed(completedResult):
            result = completedResult
        case let .rejected(rejection):
            throw .advanceRejected(rejection)
        }

        guard result.initialCursor == expectedCursor,
              result.finalCursor == expectedCursor.advanced(),
              result.completedStepCount.rawValue == 1,
              result.finalPresentationSnapshot.cursor == result.finalCursor
        else {
            throw .advanceResultMismatch(
                expectedInitialCursor: expectedCursor,
                result: result
            )
        }

        return result
    }
}
