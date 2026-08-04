import Foundation
import Testing
@testable import Engine2

struct SimulationReplayFileTests {
    @Test func versionOneJSONRoundTripsWithStableSetOrdering() throws {
        let recordingID = UUID(
            uuidString: "10000000-0000-0000-0000-000000000001"
        )!
        let originalSessionID = SimulationSessionID(
            rawValue: UUID(
                uuidString: "20000000-0000-0000-0000-000000000002"
            )!
        )
        let baseline = try SimulationReplayInputSnapshot(
            recording: inputSnapshot(
                revision: InputRevision(session: 8, sequence: 2),
                pointerPosition: SIMD2<Float>(3, 4),
                pointerMotionTotal: SIMD2<Float>(7, -2),
                scrollTotal: SIMD2<Float>(0, 5),
                pressedMouseButtons: [.other(9), .middle, .left],
                pressedKeys: [
                    KeyboardKey(keyCode: 6, displayName: "Z"),
                    KeyboardKey(keyCode: 0, displayName: "A")
                ]
            )
        )
        let nextSnapshot = try SimulationReplayInputSnapshot(
            recording: inputSnapshot(
                revision: InputRevision(session: 8, sequence: 5),
                pointerPosition: SIMD2<Float>(9, 1),
                pointerMotionTotal: SIMD2<Float>(12, 0),
                scrollTotal: SIMD2<Float>(0, 9),
                pressedMouseButtons: [.right],
                pressedKeys: [
                    KeyboardKey(keyCode: 2, displayName: "D")
                ]
            )
        )
        let file = try SimulationReplayFile(
            recordingID: recordingID,
            contentIdentifier: BasicGameRecording.contentIdentifier,
            originalSessionID: originalSessionID,
            initialInputBaseline: baseline,
            terminalTick: SimulationTick(rawValue: 7),
            entries: [
                try SimulationReplayEntry(
                    tick: SimulationTick(rawValue: 3),
                    inputAssignment: .rebaseThenIngest(
                        baseline: baseline,
                        snapshot: nextSnapshot
                    )
                )
            ]
        )
        let writer = SimulationReplayWriter()
        let firstData = try writer.data(for: file)
        let secondData = try writer.data(for: file)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(
            "Engine2-\(UUID().uuidString).simulation-replay.json"
        )
        defer {
            try? FileManager.default.removeItem(at: url)
        }

        try writer.write(file, to: url)
        let decoded = try SimulationReplayReader().read(from: url)

        #expect(firstData == secondData)
        #expect(decoded == file)
        #expect(decoded.schemaVersion == .version1)
        #expect(decoded.recordingID == recordingID)
        #expect(decoded.originalSessionID == originalSessionID)
        #expect(
            decoded.initialInputBaseline?.pressedMouseButtons
                == [.left, .middle, .other(9)]
        )
        #expect(
            decoded.initialInputBaseline?.pressedKeys.map(\.displayName)
                == ["A", "Z"]
        )
    }

    @Test func readerRejectsAnUnknownSchemaVersion() throws {
        let writer = SimulationReplayWriter()
        let file = try emptyFile()
        let encoded = try writer.data(for: file)
        var object = try #require(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        object["schemaVersion"] = 99
        let unsupported = try JSONSerialization.data(withJSONObject: object)

        do {
            _ = try SimulationReplayReader().decode(unsupported)
            Issue.record("Expected the replay reader to reject an unknown schema version.")
        } catch let DecodingError.dataCorrupted(context) {
            #expect(
                context.debugDescription
                    == "Unsupported Simulation replay schema version 99."
            )
        } catch {
            Issue.record("Unexpected schema-version error: \(error)")
        }
    }

    @Test func readerRejectsNonfiniteInputCoordinates() throws {
        let baseline = try SimulationReplayInputSnapshot(
            recording: inputSnapshot(
                revision: InputRevision(session: 1, sequence: 1)
            )
        )
        let file = try SimulationReplayFile(
            recordingID: UUID(),
            contentIdentifier: BasicGameRecording.contentIdentifier,
            originalSessionID: nil,
            initialInputBaseline: baseline,
            terminalTick: .zero,
            entries: []
        )
        let encoded = try SimulationReplayWriter().data(for: file)
        var object = try #require(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        var encodedBaseline = try #require(
            object["initialInputBaseline"] as? [String: Any]
        )
        var pointerPosition = try #require(
            encodedBaseline["pointerPosition"] as? [String: Any]
        )
        pointerPosition["x"] = "NaN"
        encodedBaseline["pointerPosition"] = pointerPosition
        object["initialInputBaseline"] = encodedBaseline
        let nonfinite = try JSONSerialization.data(withJSONObject: object)

        do {
            _ = try SimulationReplayReader().decode(nonfinite)
            Issue.record("Expected the replay reader to reject nonfinite Input.")
        } catch let DecodingError.dataCorrupted(context) {
            #expect(
                context.debugDescription
                    == SimulationReplayError.nonfiniteInputVector.description
            )
        } catch {
            Issue.record("Unexpected nonfinite-input error: \(error)")
        }
    }

    @Test func constructionRequiresStrictlyIncreasingPositiveInputTicks() throws {
        let assignment = try replayAssignment()
        let tickOne = SimulationTick(rawValue: 1)
        let tickTwo = SimulationTick(rawValue: 2)
        let first = try SimulationReplayEntry(
            tick: tickTwo,
            inputAssignment: assignment
        )
        let outOfOrder = try SimulationReplayEntry(
            tick: tickOne,
            inputAssignment: assignment
        )

        #expect(
            throws: SimulationReplayError.inputEntryTicksNotStrictlyIncreasing(
                previous: tickTwo,
                current: tickOne
            )
        ) {
            try SimulationReplayFile(
                recordingID: UUID(),
                contentIdentifier: BasicGameRecording.contentIdentifier,
                originalSessionID: nil,
                initialInputBaseline: nil,
                terminalTick: tickTwo,
                entries: [first, outOfOrder]
            )
        }
        #expect(throws: SimulationReplayError.inputEntryTickIsZero) {
            try SimulationReplayEntry(
                tick: .zero,
                inputAssignment: assignment
            )
        }
        #expect(
            throws: SimulationReplayError.inputEntryAfterTerminalTick(
                entryTick: tickTwo,
                terminalTick: tickOne
            )
        ) {
            try SimulationReplayFile(
                recordingID: UUID(),
                contentIdentifier: BasicGameRecording.contentIdentifier,
                originalSessionID: nil,
                initialInputBaseline: nil,
                terminalTick: tickOne,
                entries: [first]
            )
        }
    }

    private func emptyFile() throws -> SimulationReplayFile {
        try SimulationReplayFile(
            recordingID: UUID(
                uuidString: "30000000-0000-0000-0000-000000000003"
            )!,
            contentIdentifier: BasicGameRecording.contentIdentifier,
            originalSessionID: nil,
            initialInputBaseline: nil,
            terminalTick: .zero,
            entries: []
        )
    }

    private func replayAssignment() throws -> SimulationReplayInputAssignment {
        try SimulationReplayInputAssignment(
            recording: .ingest(
                inputSnapshot(
                    revision: InputRevision(session: 2, sequence: 1)
                )
            )
        )
    }

    private func inputSnapshot(
        revision: InputRevision,
        pointerPosition: SIMD2<Float> = .zero,
        pointerMotionTotal: SIMD2<Float> = .zero,
        scrollTotal: SIMD2<Float> = .zero,
        pressedMouseButtons: Set<MouseButton> = [],
        pressedKeys: Set<KeyboardKey> = []
    ) -> InputSnapshot {
        InputSnapshot(
            revision: revision,
            pointerPosition: pointerPosition,
            pointerMotionTotal: pointerMotionTotal,
            scrollTotal: scrollTotal,
            pressedMouseButtons: pressedMouseButtons,
            pressedKeys: pressedKeys
        )
    }
}
