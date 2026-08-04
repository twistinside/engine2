import Foundation

/// Complete ordered presentation history produced by one recorded replay.
///
/// The first value is the fresh session's tick-zero presentation. Every later
/// value is the exact completed presentation returned for the corresponding
/// tick through the file's terminal tick.
nonisolated struct SimulationReplayResult: Equatable, Sendable {
    let recordingID: UUID
    let contentIdentifier: RecordingContentIdentifier
    let originalSessionID: SimulationSessionID?
    let presentationSnapshots: [SimulationPresentationSnapshot]

    var replaySessionID: SimulationSessionID {
        initialPresentationSnapshot.cursor.sessionID
    }

    var initialPresentationSnapshot: SimulationPresentationSnapshot {
        presentationSnapshots[0]
    }

    var terminalPresentationSnapshot: SimulationPresentationSnapshot {
        presentationSnapshots[presentationSnapshots.count - 1]
    }

    init(
        recordingID: UUID,
        contentIdentifier: RecordingContentIdentifier,
        originalSessionID: SimulationSessionID?,
        presentationSnapshots: [SimulationPresentationSnapshot]
    ) {
        precondition(
            presentationSnapshots.isEmpty == false,
            "A Simulation replay result must include its tick-zero presentation."
        )

        let sessionID = presentationSnapshots[0].cursor.sessionID
        for (index, snapshot) in presentationSnapshots.enumerated() {
            precondition(
                snapshot.cursor.sessionID == sessionID
                    && snapshot.cursor.tick.rawValue == UInt64(index),
                "Simulation replay presentations must form one ordered fresh session."
            )
        }

        self.recordingID = recordingID
        self.contentIdentifier = contentIdentifier
        self.originalSessionID = originalSessionID
        self.presentationSnapshots = presentationSnapshots
    }
}
