import Testing
@testable import Engine2

struct SimulationRuntimeMissileInputTests {
    @Test func rejectedFireRemainsAvailableAndAcceptedBatchesDoNotReplayIt() async throws {
        let input = InputRuntime(mappingConfiguration: .miningGame)
        input.start()
        let simulation = SimulationRuntime(
            worldBuilder: MiningWorldBuilder(),
            configuration: .miningGame,
            behavior: MiningSimulationBehavior(),
            inputBaseline: input.latestInputSnapshot
        )
        let initialCursor = simulation.currentCursor
        let initialPresentation = simulation.latestPresentationSnapshot
        let staleCursor = SimulationCursor(
            sessionID: initialCursor.sessionID,
            tick: SimulationTick(rawValue: 1)
        )
        input.receive(.keyDown(KeyboardKey(keyCode: 46)))
        input.receive(.keyUp(KeyboardKey(keyCode: 46)))
        let fireSnapshot = input.latestInputSnapshot

        let rejected = await simulation.advance(
            SimulationAdvanceRequest(
                expectedCursor: staleCursor,
                stepCount: SimulationStepCount(rawValue: 3),
                inputAssignment: .ingest(fireSnapshot),
                orbitCircularizationCommand: nil
            )
        )

        switch rejected {
        case let .rejected(reason):
            #expect(reason == .cursorMismatch(expected: staleCursor, current: initialCursor))
        case .completed:
            Issue.record("A stale cursor must reject missile input before consuming it.")
            return
        }
        #expect(simulation.currentCursor == initialCursor)
        #expect(simulation.latestPresentationSnapshot == initialPresentation)
        #expect(simulation.world.fireableComponents.entities.isEmpty)

        let accepted = await simulation.advance(
            SimulationAdvanceRequest(
                expectedCursor: initialCursor,
                stepCount: SimulationStepCount(rawValue: 3),
                inputAssignment: .ingest(fireSnapshot),
                orbitCircularizationCommand: nil
            )
        )
        guard case let .completed(firstResult) = accepted else {
            Issue.record("The corrected cursor must accept the unconsumed fire press.")
            return
        }
        let missile = try #require(simulation.world.fireableComponents.entities.first)
        #expect(simulation.world.fireableComponents.entities == [missile])
        #expect(firstResult.completedStepCount.rawValue == 3)
        #expect(firstResult.finalPresentationSnapshot.entityPresentations.contains { $0.id == missile })
        #expect(simulation.world.input.isFireRequested == false)

        let repeated = await simulation.advance(
            SimulationAdvanceRequest(
                expectedCursor: firstResult.finalCursor,
                stepCount: SimulationStepCount(rawValue: 3),
                inputAssignment: .ingest(fireSnapshot),
                orbitCircularizationCommand: nil
            )
        )
        guard case let .completed(secondResult) = repeated else {
            Issue.record("The next cursor-qualified batch must complete.")
            return
        }
        #expect(secondResult.completedStepCount.rawValue == 3)
        #expect(simulation.world.fireableComponents.entities == [missile])
    }

    @Test func rebaseSuppressesHistoricalFireAndTransitionPreservesOnlyTheNewPress() async throws {
        let input = InputRuntime(mappingConfiguration: .miningGame)
        input.start()
        let simulation = SimulationRuntime(
            worldBuilder: MiningWorldBuilder(),
            configuration: .miningGame,
            behavior: MiningSimulationBehavior(),
            inputBaseline: input.latestInputSnapshot
        )
        input.receive(.keyDown(KeyboardKey(keyCode: 46)))
        input.receive(.keyUp(KeyboardKey(keyCode: 46)))
        let historicalSnapshot = input.latestInputSnapshot

        let rebased = await simulation.advance(
            SimulationAdvanceRequest(
                expectedCursor: simulation.currentCursor,
                stepCount: SimulationStepCount(rawValue: 3),
                inputAssignment: .rebase(historicalSnapshot),
                orbitCircularizationCommand: nil
            )
        )
        guard case let .completed(rebaseResult) = rebased else {
            Issue.record("The cursor-qualified rebase must complete.")
            return
        }
        #expect(rebaseResult.completedStepCount.rawValue == 3)
        #expect(simulation.world.fireableComponents.entities.isEmpty)

        input.receive(.keyDown(KeyboardKey(keyCode: 46)))
        input.receive(.keyUp(KeyboardKey(keyCode: 46)))
        let transitionBaseline = input.latestInputSnapshot
        let transitionWithoutNewPress = await simulation.advance(
            SimulationAdvanceRequest(
                expectedCursor: rebaseResult.finalCursor,
                stepCount: SimulationStepCount(rawValue: 3),
                inputAssignment: .rebaseThenIngest(
                    baseline: transitionBaseline,
                    snapshot: transitionBaseline
                ),
                orbitCircularizationCommand: nil
            )
        )
        guard case let .completed(baselineResult) = transitionWithoutNewPress else {
            Issue.record("The transition without subsequent input must complete.")
            return
        }
        #expect(simulation.world.fireableComponents.entities.isEmpty)

        input.receive(.keyDown(KeyboardKey(keyCode: 46)))
        input.receive(.keyUp(KeyboardKey(keyCode: 46)))
        let transitionWithNewPress = await simulation.advance(
            SimulationAdvanceRequest(
                expectedCursor: baselineResult.finalCursor,
                stepCount: SimulationStepCount(rawValue: 3),
                inputAssignment: .rebaseThenIngest(
                    baseline: transitionBaseline,
                    snapshot: input.latestInputSnapshot
                ),
                orbitCircularizationCommand: nil
            )
        )
        guard case let .completed(transitionResult) = transitionWithNewPress else {
            Issue.record("The post-baseline fire press must advance with its exact request.")
            return
        }
        let missile = try #require(simulation.world.fireableComponents.entities.first)
        #expect(simulation.world.fireableComponents.entities == [missile])
        #expect(transitionResult.completedStepCount.rawValue == 3)
        #expect(transitionResult.finalPresentationSnapshot.entityPresentations.contains { $0.id == missile })
        #expect(simulation.world.input.isFireRequested == false)
    }
}
