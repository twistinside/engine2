import Foundation
import simd
import Testing
@testable import Engine2

struct SimulationRuntimeAdvanceTests {
    @Test @MainActor func initialCursorQualifiesTickZeroAndPresentation() {
        let sessionID = SimulationSessionID(
            rawValue: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!
        )
        let simulation = makeSimulation(sessionID: sessionID)

        #expect(
            simulation.currentCursor == SimulationCursor(
                sessionID: sessionID,
                tick: .zero
            )
        )
        #expect(simulation.latestPresentationSnapshot.cursor == simulation.currentCursor)
    }

    @Test @MainActor func boundedAdvanceRunsCompleteScheduleAndReturnsExactSnapshot() async throws {
        let simulation = makeSimulation()
        let initialCursor = simulation.currentCursor
        let request = SimulationAdvanceRequest(
            expectedCursor: initialCursor,
            stepCount: SimulationStepCount(rawValue: 3)
        )

        let outcome = await simulation.advance(request)
        let result = try completedResult(from: outcome)
        let entity = try #require(
            simulation.world.positionComponents.entities.first
        )

        #expect(result.initialCursor == initialCursor)
        #expect(result.finalCursor.sessionID == initialCursor.sessionID)
        #expect(result.finalCursor.tick == SimulationTick(rawValue: 3))
        #expect(result.completedStepCount.rawValue == 3)
        #expect(result.finalPresentationSnapshot.cursor == result.finalCursor)
        #expect(simulation.latestPresentationSnapshot == result.finalPresentationSnapshot)
        #expect(simulation.currentCursor == result.finalCursor)
        #expect(simulation.world.positionComponents[entity]?.position == SIMD3<Float>(3, 0, 0))
    }

    @Test @MainActor func staleExpectedCursorRejectsWithoutMutation() async {
        let simulation = makeSimulation()
        let initialCursor = simulation.currentCursor
        let initialSnapshot = simulation.latestPresentationSnapshot
        let staleCursor = SimulationCursor(
            sessionID: initialCursor.sessionID,
            tick: SimulationTick(rawValue: 4)
        )
        let request = SimulationAdvanceRequest(
            expectedCursor: staleCursor,
            stepCount: .one,
            inputAssignment: .ingest(
                inputSnapshot(
                    revision: InputRevision(session: 9, sequence: 2),
                    pointerMotion: SIMD2<Float>(7, 3)
                )
            )
        )

        let outcome = await simulation.advance(request)

        #expect(
            outcome == .rejected(
                .cursorMismatch(
                    expected: staleCursor,
                    current: initialCursor
                )
            )
        )
        #expect(simulation.currentCursor == initialCursor)
        #expect(simulation.latestPresentationSnapshot == initialSnapshot)
        #expect(simulation.world.input.history.isEmpty)
    }

    @Test @MainActor func rebuildStartsANewSessionAtTickZero() async throws {
        let simulation = makeSimulation()
        let firstResult = try completedResult(
            from: await simulation.advance(
                SimulationAdvanceRequest(stepCount: .one)
            )
        )

        simulation.rebuildWorld()

        #expect(simulation.currentCursor.sessionID != firstResult.finalCursor.sessionID)
        #expect(simulation.currentCursor.tick == .zero)
        #expect(simulation.latestPresentationSnapshot.cursor == simulation.currentCursor)
    }

    @Test @MainActor func sequentialRequestsDoNotReplaceTheSession() async throws {
        let simulation = makeSimulation()
        let sessionID = simulation.sessionID

        let first = try completedResult(
            from: await simulation.advance(
                SimulationAdvanceRequest(stepCount: .one)
            )
        )
        _ = try completedResult(
            from: await simulation.advance(
                SimulationAdvanceRequest(
                    expectedCursor: first.finalCursor,
                    stepCount: .one
                )
            )
        )

        #expect(simulation.sessionID == sessionID)
        #expect(simulation.currentCursor.tick == SimulationTick(rawValue: 2))
    }

    @Test @MainActor func runtimeDoesNotAdvanceWithoutAnExplicitRequest() async {
        let simulation = makeSimulation()
        let cursor = simulation.currentCursor

        await Task.yield()

        #expect(simulation.currentCursor == cursor)
    }

    @Test @MainActor func batchIngestsTransientInputOnlyOnItsFirstTick() async throws {
        let simulation = makeSimulation()
        let request = SimulationAdvanceRequest(
            stepCount: SimulationStepCount(rawValue: 3),
            inputAssignment: .ingest(
                inputSnapshot(
                    revision: InputRevision(session: 3, sequence: 1),
                    pointerMotion: SIMD2<Float>(5, 0),
                    pressedKeys: [KeyboardKey(keyCode: 13, displayName: "W")]
                )
            )
        )

        _ = try completedResult(from: await simulation.advance(request))

        #expect(simulation.world.input.history.count == 2)
        #expect(simulation.world.input.history[0].tokens == ["W"])
        #expect(simulation.world.input.history[0].frameCount == 2)
        #expect(simulation.world.input.history[1].tokens == ["Mouse dx:+5 dy:+0", "W"])
        #expect(simulation.world.input.history[1].frameCount == 1)
        #expect(simulation.world.input.mouse.delta == .zero)
    }

    @Test @MainActor func rebaseCarriesHeldStateWithoutHistoricalTransients() async throws {
        let simulation = makeSimulation()
        let request = SimulationAdvanceRequest(
            stepCount: SimulationStepCount(rawValue: 2),
            inputAssignment: .rebase(
                inputSnapshot(
                    revision: InputRevision(session: 6, sequence: 8),
                    pointerMotion: SIMD2<Float>(12, -4),
                    pressedKeys: [KeyboardKey(keyCode: 13, displayName: "W")]
                )
            )
        )

        _ = try completedResult(from: await simulation.advance(request))

        #expect(simulation.world.input.history.count == 1)
        #expect(simulation.world.input.history[0].tokens == ["W"])
        #expect(simulation.world.input.history[0].frameCount == 2)
        #expect(simulation.world.input.mouse.delta == .zero)
    }

    @Test @MainActor func transitionRebasesThenIngestsOnlyPostBaselineInput() async throws {
        let simulation = makeSimulation()
        let baseline = inputSnapshot(
            revision: InputRevision(session: 7, sequence: 4),
            pointerMotion: SIMD2<Float>(12, -4),
            pressedKeys: [KeyboardKey(keyCode: 13, displayName: "W")]
        )
        let subsequentSnapshot = inputSnapshot(
            revision: InputRevision(session: 7, sequence: 9),
            pointerMotion: SIMD2<Float>(17, -1),
            pressedKeys: [KeyboardKey(keyCode: 2, displayName: "D")]
        )
        let request = SimulationAdvanceRequest(
            stepCount: SimulationStepCount(rawValue: 3),
            inputAssignment: .rebaseThenIngest(
                baseline: baseline,
                snapshot: subsequentSnapshot
            )
        )

        _ = try completedResult(from: await simulation.advance(request))

        #expect(simulation.world.input.history.count == 2)
        #expect(simulation.world.input.history[0].tokens == ["D"])
        #expect(simulation.world.input.history[0].frameCount == 2)
        #expect(
            simulation.world.input.history[1].tokens == [
                "Mouse dx:+5 dy:+3",
                "D"
            ]
        )
        #expect(simulation.world.input.history[1].frameCount == 1)
        #expect(simulation.world.input.keyboard.keys == subsequentSnapshot.pressedKeys)
        #expect(simulation.world.input.mouse.position == subsequentSnapshot.pointerPosition)
        #expect(simulation.world.input.mouse.delta == .zero)
    }

    @Test @MainActor func cursorMismatchRejectsTransitionWithoutChangingInput() async {
        let simulation = makeSimulation()
        let currentCursor = simulation.currentCursor
        let staleCursor = SimulationCursor(
            sessionID: currentCursor.sessionID,
            tick: SimulationTick(rawValue: 12)
        )
        let request = SimulationAdvanceRequest(
            expectedCursor: staleCursor,
            stepCount: .one,
            inputAssignment: .rebaseThenIngest(
                baseline: inputSnapshot(
                    revision: InputRevision(session: 3, sequence: 2),
                    pointerMotion: SIMD2<Float>(8, 1),
                    pressedKeys: [KeyboardKey(keyCode: 13, displayName: "W")]
                ),
                snapshot: inputSnapshot(
                    revision: InputRevision(session: 3, sequence: 3),
                    pointerMotion: SIMD2<Float>(11, 2),
                    pressedKeys: [KeyboardKey(keyCode: 2, displayName: "D")]
                )
            )
        )

        let outcome = await simulation.advance(request)

        #expect(
            outcome == .rejected(
                .cursorMismatch(expected: staleCursor, current: currentCursor)
            )
        )
        #expect(simulation.currentCursor == currentCursor)
        #expect(simulation.world.input.keyboard.keys.isEmpty)
        #expect(simulation.world.input.mouse.position == .zero)
        #expect(simulation.world.input.history.isEmpty)
    }

    @Test @MainActor func simultaneousExpectedCursorRequestsCannotDoubleAdvance() async {
        let simulation = makeSimulation()
        let initialCursor = simulation.currentCursor
        let request = SimulationAdvanceRequest(
            expectedCursor: initialCursor,
            stepCount: .one
        )

        async let firstOutcome = simulation.advance(request)
        async let secondOutcome = simulation.advance(request)
        let outcomes = await [firstOutcome, secondOutcome]
        let completedCount = outcomes.filter { outcome in
            if case .completed = outcome {
                return true
            }
            return false
        }.count
        let rejectedCount = outcomes.filter { outcome in
            if case .rejected(.cursorMismatch) = outcome {
                return true
            }
            return false
        }.count

        #expect(completedCount == 1)
        #expect(rejectedCount == 1)
        #expect(simulation.currentCursor.tick == SimulationTick(rawValue: 1))
    }

    @Test @MainActor func returnedSnapshotRemainsDetachedFromLaterAdvances() async throws {
        let simulation = makeSimulation()
        let first = try completedResult(
            from: await simulation.advance(
                SimulationAdvanceRequest(stepCount: .one)
            )
        )

        _ = try completedResult(
            from: await simulation.advance(
                SimulationAdvanceRequest(
                    expectedCursor: first.finalCursor,
                    stepCount: .one
                )
            )
        )

        #expect(first.finalPresentationSnapshot.cursor.tick == SimulationTick(rawValue: 1))
        #expect(first.finalPresentationSnapshot.entityPresentations.first?.position == SIMD3<Float>(1, 0, 0))
        #expect(simulation.latestPresentationSnapshot.cursor.tick == SimulationTick(rawValue: 2))
        #expect(simulation.latestPresentationSnapshot.entityPresentations.first?.position == SIMD3<Float>(2, 0, 0))
    }

    @MainActor
    private func makeSimulation(
        sessionID: SimulationSessionID = SimulationSessionID()
    ) -> SimulationRuntime {
        SimulationRuntime(
            worldBuilder: MovingWorldBuilder(),
            sessionID: sessionID
        )
    }

    private func completedResult(
        from outcome: SimulationAdvanceOutcome
    ) throws -> SimulationAdvanceResult {
        guard case let .completed(result) = outcome else {
            Issue.record("Expected a completed Simulation advance, received \(outcome)")
            throw UnexpectedOutcome()
        }
        return result
    }

    private func inputSnapshot(
        revision: InputRevision,
        pointerMotion: SIMD2<Float>,
        pressedKeys: Set<KeyboardKey> = []
    ) -> InputSnapshot {
        InputSnapshot(
            revision: revision,
            pointerPosition: pointerMotion,
            pointerMotionTotal: pointerMotion,
            scrollTotal: .zero,
            pressedMouseButtons: [],
            pressedKeys: pressedKeys
        )
    }

    private struct MovingWorldBuilder: PWorldBuilder {
        func buildWorld() -> World {
            let world = World()
            _ = Ball(
                in: world,
                position: .zero,
                velocity: SIMD3<Float>(
                    1 / SimulationRuntime.fixedTimeStep.seconds,
                    0,
                    0
                )
            )
            return world
        }
    }

    private struct UnexpectedOutcome: Error {}
}
