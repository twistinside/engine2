import Foundation
import simd
import Testing
@testable import Engine2

struct SimulationRuntimeAdvanceTests {
    @Test func initialCursorQualifiesTickZeroAndPresentation() {
        let rawSessionID = UUID(uuidString: "10000000-0000-0000-0000-000000000001")!
        let sessionID = SimulationSessionID(
            rawValue: rawSessionID
        )
        let simulation = makeSimulation(sessionID: sessionID)
        let expectedCursor = SimulationCursor(
            sessionID: sessionID,
            tick: .zero
        )

        #expect(simulation.currentCursor == expectedCursor)
        #expect(simulation.latestPresentationSnapshot.cursor == simulation.currentCursor)
    }

    @Test func boundedAdvanceRunsCompleteScheduleAndReturnsExactSnapshot() async throws {
        let simulation = makeSimulation()
        let initialCursor = simulation.currentCursor
        let stepCount = SimulationStepCount(rawValue: 3)
        let request = SimulationAdvanceRequest(
            expectedCursor: initialCursor,
            stepCount: stepCount,
            inputAssignment: .none
        )

        let outcome = await simulation.advance(request)
        let result = try completedResult(from: outcome)
        let entity = try #require(
            simulation.world.positionComponents.entities.first
        )
        let expectedTick = SimulationTick(rawValue: 3)

        #expect(result.initialCursor == initialCursor)
        #expect(result.finalCursor.sessionID == initialCursor.sessionID)
        #expect(result.finalCursor.tick == expectedTick)
        #expect(result.completedStepCount.rawValue == 3)
        #expect(result.finalPresentationSnapshot.cursor == result.finalCursor)
        #expect(simulation.latestPresentationSnapshot == result.finalPresentationSnapshot)
        #expect(simulation.currentCursor == result.finalCursor)
        #expect(simulation.world.positionComponents[entity]?.position == SIMD3<Float>(3, 0, 0))
    }

    @Test func staleExpectedCursorRejectsWithoutMutation() async {
        let simulation = makeSimulation()
        let initialCursor = simulation.currentCursor
        let initialSnapshot = simulation.latestPresentationSnapshot
        let staleTick = SimulationTick(rawValue: 4)
        let staleCursor = SimulationCursor(
            sessionID: initialCursor.sessionID,
            tick: staleTick
        )
        let inputRevision = InputRevision(session: 9, sequence: 2)
        let snapshot = inputSnapshot(
            revision: inputRevision,
            pointerMotion: SIMD2<Float>(7, 3)
        )
        let request = SimulationAdvanceRequest(
            expectedCursor: staleCursor,
            stepCount: .one,
            inputAssignment: .ingest(snapshot)
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
        #expect(simulation.world.inputHistory.entries.isEmpty)
    }

    @Test func rebuildStartsANewSessionAtTickZero() async throws {
        let simulation = makeSimulation()
        let request = SimulationAdvanceRequest(
            expectedCursor: nil,
            stepCount: .one,
            inputAssignment: .none
        )
        let firstResult = try completedResult(
            from: await simulation.advance(request)
        )

        simulation.rebuildWorld(inputBaseline: nil)

        #expect(simulation.currentCursor.sessionID != firstResult.finalCursor.sessionID)
        #expect(simulation.currentCursor.tick == .zero)
        #expect(simulation.latestPresentationSnapshot.cursor == simulation.currentCursor)
    }

    @Test func sequentialRequestsDoNotReplaceTheSession() async throws {
        let simulation = makeSimulation()
        let sessionID = simulation.sessionID

        let firstRequest = SimulationAdvanceRequest(
            expectedCursor: nil,
            stepCount: .one,
            inputAssignment: .none
        )
        let first = try completedResult(
            from: await simulation.advance(firstRequest)
        )
        let secondRequest = SimulationAdvanceRequest(
            expectedCursor: first.finalCursor,
            stepCount: .one,
            inputAssignment: .none
        )
        _ = try completedResult(
            from: await simulation.advance(secondRequest)
        )

        let expectedTick = SimulationTick(rawValue: 2)
        #expect(simulation.sessionID == sessionID)
        #expect(simulation.currentCursor.tick == expectedTick)
    }

    @Test func runtimeDoesNotAdvanceWithoutAnExplicitRequest() async {
        let simulation = makeSimulation()
        let cursor = simulation.currentCursor

        await Task.yield()

        #expect(simulation.currentCursor == cursor)
    }

    @Test func batchIngestsTransientInputOnlyOnItsFirstTick() async throws {
        let simulation = makeSimulation()
        let initialCamera = simulation.world.camera
        let stepCount = SimulationStepCount(rawValue: 3)
        let inputRevision = InputRevision(session: 3, sequence: 1)
        let pressedKey = KeyboardKey(keyCode: 13, displayName: "W")
        let snapshot = inputSnapshot(
            revision: inputRevision,
            pointerMotion: SIMD2<Float>(5, 0),
            pressedKeys: [pressedKey]
        )
        let request = SimulationAdvanceRequest(
            expectedCursor: nil,
            stepCount: stepCount,
            inputAssignment: .ingest(snapshot)
        )

        let result = try completedResult(from: await simulation.advance(request))

        #expect(simulation.world.inputHistory.entries.count == 2)
        #expect(simulation.world.inputHistory.entries[0].tokens == ["W"])
        #expect(simulation.world.inputHistory.entries[0].frameCount == 2)
        #expect(simulation.world.inputHistory.entries[1].tokens == ["Mouse dx:+5 dy:+0", "W"])
        #expect(simulation.world.inputHistory.entries[1].frameCount == 1)
        #expect(simulation.world.input.mouse.delta == .zero)
        let expectedCameraPosition = SIMD3<Float>(
            sinf(0.05) * 8,
            0,
            cosf(0.05) * 8
        )
        let expectedCamera = Camera.lookingAt(
            .zero,
            from: expectedCameraPosition,
            up: SIMD3<Float>(0, 1, 0),
            projection: .standardPerspective
        )
        #expect(simd_distance(simulation.world.camera.position, expectedCamera.position) < 0.0001)
        #expect(
            simd_distance(
                simulation.world.camera.rotation.vector,
                expectedCamera.rotation.vector
            ) < 0.0001
        )
        #expect(simulation.world.camera != initialCamera)
        #expect(result.finalPresentationSnapshot.camera == simulation.world.camera)
    }

    @Test func rebaseCarriesHeldStateWithoutHistoricalTransients() async throws {
        let simulation = makeSimulation()
        let initialCamera = simulation.world.camera
        let stepCount = SimulationStepCount(rawValue: 2)
        let inputRevision = InputRevision(session: 6, sequence: 8)
        let pressedKey = KeyboardKey(keyCode: 13, displayName: "W")
        let snapshot = inputSnapshot(
            revision: inputRevision,
            pointerMotion: SIMD2<Float>(12, -4),
            pressedKeys: [pressedKey]
        )
        let request = SimulationAdvanceRequest(
            expectedCursor: nil,
            stepCount: stepCount,
            inputAssignment: .rebase(snapshot)
        )

        _ = try completedResult(from: await simulation.advance(request))

        #expect(simulation.world.inputHistory.entries.count == 1)
        #expect(simulation.world.inputHistory.entries[0].tokens == ["W"])
        #expect(simulation.world.inputHistory.entries[0].frameCount == 2)
        #expect(simulation.world.input.mouse.delta == .zero)
        #expect(simulation.world.camera == initialCamera)
    }

    @Test func transitionRebasesThenIngestsOnlyPostBaselineInput() async throws {
        let simulation = makeSimulation()
        let initialCamera = simulation.world.camera
        let baselineRevision = InputRevision(session: 7, sequence: 4)
        let baselineKey = KeyboardKey(keyCode: 13, displayName: "W")
        let baseline = inputSnapshot(
            revision: baselineRevision,
            pointerMotion: SIMD2<Float>(12, -4),
            pressedKeys: [baselineKey]
        )
        let subsequentRevision = InputRevision(session: 7, sequence: 9)
        let subsequentKey = KeyboardKey(keyCode: 2, displayName: "D")
        let subsequentSnapshot = inputSnapshot(
            revision: subsequentRevision,
            pointerMotion: SIMD2<Float>(17, -1),
            pressedKeys: [subsequentKey]
        )
        let stepCount = SimulationStepCount(rawValue: 3)
        let request = SimulationAdvanceRequest(
            expectedCursor: nil,
            stepCount: stepCount,
            inputAssignment: .rebaseThenIngest(
                baseline: baseline,
                snapshot: subsequentSnapshot
            )
        )

        let result = try completedResult(from: await simulation.advance(request))

        #expect(simulation.world.inputHistory.entries.count == 2)
        #expect(simulation.world.inputHistory.entries[0].tokens == ["D"])
        #expect(simulation.world.inputHistory.entries[0].frameCount == 2)
        #expect(
            simulation.world.inputHistory.entries[1].tokens == [
                "Mouse dx:+5 dy:+3",
                "D"
            ]
        )
        #expect(simulation.world.inputHistory.entries[1].frameCount == 1)
        #expect(simulation.world.input.keyboard.keys == subsequentSnapshot.pressedKeys)
        #expect(simulation.world.input.mouse.position == subsequentSnapshot.pointerPosition)
        #expect(simulation.world.input.mouse.delta == .zero)
        let expectedCameraPosition = SIMD3<Float>(
            sinf(0.05) * 8,
            0,
            cosf(0.05) * 8
        )
        let expectedCamera = Camera.lookingAt(
            .zero,
            from: expectedCameraPosition,
            up: SIMD3<Float>(0, 1, 0),
            projection: .standardPerspective
        )
        #expect(simd_distance(simulation.world.camera.position, expectedCamera.position) < 0.0001)
        #expect(
            simd_distance(
                simulation.world.camera.rotation.vector,
                expectedCamera.rotation.vector
            ) < 0.0001
        )
        #expect(simulation.world.camera != initialCamera)
        #expect(result.finalPresentationSnapshot.camera == simulation.world.camera)
    }

    @Test func cursorMismatchRejectsTransitionWithoutChangingInput() async {
        let simulation = makeSimulation()
        let currentCursor = simulation.currentCursor
        let staleTick = SimulationTick(rawValue: 12)
        let staleCursor = SimulationCursor(
            sessionID: currentCursor.sessionID,
            tick: staleTick
        )
        let baselineRevision = InputRevision(session: 3, sequence: 2)
        let baselineKey = KeyboardKey(keyCode: 13, displayName: "W")
        let baseline = inputSnapshot(
            revision: baselineRevision,
            pointerMotion: SIMD2<Float>(8, 1),
            pressedKeys: [baselineKey]
        )
        let subsequentRevision = InputRevision(session: 3, sequence: 3)
        let subsequentKey = KeyboardKey(keyCode: 2, displayName: "D")
        let subsequentSnapshot = inputSnapshot(
            revision: subsequentRevision,
            pointerMotion: SIMD2<Float>(11, 2),
            pressedKeys: [subsequentKey]
        )
        let request = SimulationAdvanceRequest(
            expectedCursor: staleCursor,
            stepCount: .one,
            inputAssignment: .rebaseThenIngest(
                baseline: baseline,
                snapshot: subsequentSnapshot
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
        #expect(simulation.world.inputHistory.entries.isEmpty)
    }

    @Test func simultaneousExpectedCursorRequestsCannotDoubleAdvance() async {
        let simulation = makeSimulation()
        let initialCursor = simulation.currentCursor
        let request = SimulationAdvanceRequest(
            expectedCursor: initialCursor,
            stepCount: .one,
            inputAssignment: .none
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
        let expectedTick = SimulationTick(rawValue: 1)
        #expect(simulation.currentCursor.tick == expectedTick)
    }

    @Test func returnedSnapshotRemainsDetachedFromLaterAdvances() async throws {
        let simulation = makeSimulation()
        let firstRequest = SimulationAdvanceRequest(
            expectedCursor: nil,
            stepCount: .one,
            inputAssignment: .none
        )
        let first = try completedResult(
            from: await simulation.advance(firstRequest)
        )
        let secondRequest = SimulationAdvanceRequest(
            expectedCursor: first.finalCursor,
            stepCount: .one,
            inputAssignment: .none
        )

        _ = try completedResult(
            from: await simulation.advance(secondRequest)
        )

        let firstExpectedTick = SimulationTick(rawValue: 1)
        let secondExpectedTick = SimulationTick(rawValue: 2)

        #expect(first.finalPresentationSnapshot.cursor.tick == firstExpectedTick)
        #expect(first.finalPresentationSnapshot.entityPresentations.first?.position == SIMD3<Float>(1, 0, 0))
        #expect(simulation.latestPresentationSnapshot.cursor.tick == secondExpectedTick)
        #expect(simulation.latestPresentationSnapshot.entityPresentations.first?.position == SIMD3<Float>(2, 0, 0))
    }

    private func makeSimulation(sessionID: SimulationSessionID = SimulationSessionID()) -> SimulationRuntime {
        let worldBuilder = MovingWorldBuilder()
        return SimulationRuntime(
            worldBuilder: worldBuilder,
            configuration: .basicGame,
            inputBaseline: nil,
            sessionID: sessionID
        )
    }

    private func completedResult(from outcome: SimulationAdvanceOutcome) throws -> SimulationAdvanceResult {
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
            let velocity = SIMD3<Float>(
                1 / SimulationRuntime.fixedTimeStep.seconds,
                0,
                0
            )
            _ = Ball(
                in: world,
                materialID: .warmDielectric,
                position: .zero,
                velocity: velocity
            )
            return world
        }
    }

    private struct UnexpectedOutcome: Error {}
}
