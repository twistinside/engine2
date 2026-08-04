import Foundation
import Testing
@testable import Engine2

struct SimulationReplayDriverTests {
    @Test func appliesInputOnlyWhileProducingItsRecordedTick() async throws {
        let originalSessionID = SimulationSessionID(
            rawValue: UUID(
                uuidString: "40000000-0000-0000-0000-000000000004"
            )!
        )
        let file = try replayFile(
            originalSessionID: originalSessionID,
            terminalTick: SimulationTick(rawValue: 4),
            entries: [
                try SimulationReplayEntry(
                    tick: SimulationTick(rawValue: 2),
                    inputAssignment: .ingest(
                        try recordedSnapshot(
                            revision: InputRevision(session: 3, sequence: 1),
                            pointerMotionTotal: SIMD2<Float>(5, 0)
                        )
                    )
                )
            ]
        )
        let result = try await SimulationReplayDriver(
            file: file,
            expectedContentIdentifier: BasicGameRecording.contentIdentifier,
            worldBuilder: BasicWorldBuilder(),
            configuration: .basicGame
        ).run()

        #expect(result.originalSessionID == originalSessionID)
        #expect(result.replaySessionID != originalSessionID)
        #expect(result.presentationSnapshots.count == 5)
        #expect(
            result.presentationSnapshots.map(\.cursor.tick.rawValue)
                == [0, 1, 2, 3, 4]
        )
        #expect(
            result.presentationSnapshots[0].camera
                == result.presentationSnapshots[1].camera
        )
        #expect(
            result.presentationSnapshots[1].camera
                != result.presentationSnapshots[2].camera
        )
        #expect(
            result.presentationSnapshots[2].camera
                == result.presentationSnapshots[3].camera
        )
        #expect(
            result.presentationSnapshots[3].camera
                == result.presentationSnapshots[4].camera
        )
    }

    @Test func repeatedRunsProduceEquivalentPresentationValuesInFreshSessions() async throws {
        let baseline = try recordedSnapshot(
            revision: InputRevision(session: 9, sequence: 4),
            pointerMotionTotal: SIMD2<Float>(20, 0),
            scrollTotal: SIMD2<Float>(0, 3),
            pressedKeys: [
                KeyboardKey(keyCode: 13, displayName: "W")
            ]
        )
        let laterSnapshot = try recordedSnapshot(
            revision: InputRevision(session: 9, sequence: 7),
            pointerMotionTotal: SIMD2<Float>(24, 0),
            scrollTotal: SIMD2<Float>(0, 5),
            pressedKeys: [
                KeyboardKey(keyCode: 2, displayName: "D")
            ]
        )
        let file = try SimulationReplayFile(
            recordingID: UUID(
                uuidString: "50000000-0000-0000-0000-000000000005"
            )!,
            contentIdentifier: BasicGameRecording.contentIdentifier,
            originalSessionID: nil,
            initialInputBaseline: baseline,
            terminalTick: SimulationTick(rawValue: 5),
            entries: [
                try SimulationReplayEntry(
                    tick: SimulationTick(rawValue: 3),
                    inputAssignment: .rebaseThenIngest(
                        baseline: baseline,
                        snapshot: laterSnapshot
                    )
                )
            ]
        )
        let driver = SimulationReplayDriver(
            file: file,
            expectedContentIdentifier: BasicGameRecording.contentIdentifier,
            worldBuilder: BasicWorldBuilder(),
            configuration: .basicGame
        )

        let first = try await driver.run()
        let second = try await driver.run()

        #expect(first.replaySessionID != second.replaySessionID)
        #expect(first.presentationSnapshots.count == second.presentationSnapshots.count)
        for index in first.presentationSnapshots.indices {
            #expect(
                first.presentationSnapshots[index].cursor.tick
                    == second.presentationSnapshots[index].cursor.tick
            )
            #expect(
                first.presentationSnapshots[index].camera
                    == second.presentationSnapshots[index].camera
            )
            #expect(
                first.presentationSnapshots[index].entityPresentations
                    == second.presentationSnapshots[index].entityPresentations
            )
        }
    }

    @Test func rejectsContentThatDoesNotMatchTheInjectedWorldRecipe() async throws {
        let file = try replayFile(
            originalSessionID: nil,
            terminalTick: .zero,
            entries: []
        )
        let mismatchedIdentifier = RecordingContentIdentifier(
            rawValue: "engine2.other-content.v1"
        )
        let driver = SimulationReplayDriver(
            file: file,
            expectedContentIdentifier: mismatchedIdentifier,
            worldBuilder: BasicWorldBuilder(),
            configuration: .basicGame
        )

        await #expect(
            throws: SimulationReplayError.contentIdentifierMismatch(
                expected: mismatchedIdentifier,
                recorded: BasicGameRecording.contentIdentifier
            )
        ) {
            try await driver.run()
        }
    }

    private func replayFile(
        originalSessionID: SimulationSessionID?,
        terminalTick: SimulationTick,
        entries: [SimulationReplayEntry]
    ) throws -> SimulationReplayFile {
        try SimulationReplayFile(
            recordingID: UUID(),
            contentIdentifier: BasicGameRecording.contentIdentifier,
            originalSessionID: originalSessionID,
            initialInputBaseline: try recordedSnapshot(
                revision: .initial
            ),
            terminalTick: terminalTick,
            entries: entries
        )
    }

    private func recordedSnapshot(
        revision: InputRevision,
        pointerMotionTotal: SIMD2<Float> = .zero,
        scrollTotal: SIMD2<Float> = .zero,
        pressedKeys: Set<KeyboardKey> = []
    ) throws -> SimulationReplayInputSnapshot {
        try SimulationReplayInputSnapshot(
            recording: InputSnapshot(
                revision: revision,
                pointerPosition: pointerMotionTotal,
                pointerMotionTotal: pointerMotionTotal,
                scrollTotal: scrollTotal,
                pressedMouseButtons: [],
                pressedKeys: pressedKeys
            )
        )
    }
}
