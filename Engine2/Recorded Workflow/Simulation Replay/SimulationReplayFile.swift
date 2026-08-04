import Foundation

/// Versioned durable contract for reproducing one Simulation timeline from Input.
///
/// The original session identity is provenance only. Replay constructs a fresh
/// session from the injected world recipe and Simulation policy. Missing tick
/// entries assign `.none`; present entries are strictly increasing and cannot
/// extend past the declared terminal completed tick.
nonisolated struct SimulationReplayFile: Equatable, Sendable {
    let schemaVersion: SimulationReplaySchemaVersion
    let recordingID: UUID
    let contentIdentifier: RecordingContentIdentifier
    let originalSessionID: SimulationSessionID?
    let initialInputBaseline: SimulationReplayInputSnapshot?
    let terminalTick: SimulationTick
    let entries: [SimulationReplayEntry]

    init(
        recordingID: UUID,
        contentIdentifier: RecordingContentIdentifier,
        originalSessionID: SimulationSessionID?,
        initialInputBaseline: SimulationReplayInputSnapshot?,
        terminalTick: SimulationTick,
        entries: [SimulationReplayEntry]
    ) throws(SimulationReplayError) {
        var previousTick: SimulationTick?

        for entry in entries {
            if let previousTick, entry.tick <= previousTick {
                throw .inputEntryTicksNotStrictlyIncreasing(
                    previous: previousTick,
                    current: entry.tick
                )
            }
            guard entry.tick <= terminalTick else {
                throw .inputEntryAfterTerminalTick(
                    entryTick: entry.tick,
                    terminalTick: terminalTick
                )
            }
            previousTick = entry.tick
        }

        self.schemaVersion = .version1
        self.recordingID = recordingID
        self.contentIdentifier = contentIdentifier
        self.originalSessionID = originalSessionID
        self.initialInputBaseline = initialInputBaseline
        self.terminalTick = terminalTick
        self.entries = entries
    }
}

extension SimulationReplayFile: Codable {
    private enum CodingKeys: String, CodingKey {
        case contentIdentifier
        case entries
        case initialInputBaseline
        case originalSessionID
        case recordingID
        case schemaVersion
        case terminalTick
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawSchemaVersion = try container.decode(
            UInt32.self,
            forKey: .schemaVersion
        )
        guard let schemaVersion = SimulationReplaySchemaVersion(
            rawValue: rawSchemaVersion
        ) else {
            throw DecodingError.dataCorruptedError(
                forKey: .schemaVersion,
                in: container,
                debugDescription: "Unsupported Simulation replay schema version \(rawSchemaVersion)."
            )
        }
        guard schemaVersion == .version1 else {
            throw DecodingError.dataCorruptedError(
                forKey: .schemaVersion,
                in: container,
                debugDescription: "Unsupported Simulation replay schema version \(rawSchemaVersion)."
            )
        }

        let originalSessionUUID = try container.decodeIfPresent(
            UUID.self,
            forKey: .originalSessionID
        )

        do {
            try self.init(
                recordingID: container.decode(
                    UUID.self,
                    forKey: .recordingID
                ),
                contentIdentifier: container.decode(
                    RecordingContentIdentifier.self,
                    forKey: .contentIdentifier
                ),
                originalSessionID: originalSessionUUID.map {
                    SimulationSessionID(rawValue: $0)
                },
                initialInputBaseline: container.decodeIfPresent(
                    SimulationReplayInputSnapshot.self,
                    forKey: .initialInputBaseline
                ),
                terminalTick: SimulationTick(
                    rawValue: container.decode(
                        UInt64.self,
                        forKey: .terminalTick
                    )
                ),
                entries: container.decode(
                    [SimulationReplayEntry].self,
                    forKey: .entries
                )
            )
        } catch let error as SimulationReplayError {
            throw DecodingError.dataCorruptedError(
                forKey: .entries,
                in: container,
                debugDescription: error.description
            )
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(contentIdentifier, forKey: .contentIdentifier)
        try container.encode(entries, forKey: .entries)
        try container.encodeIfPresent(
            initialInputBaseline,
            forKey: .initialInputBaseline
        )
        try container.encodeIfPresent(
            originalSessionID?.rawValue,
            forKey: .originalSessionID
        )
        try container.encode(recordingID, forKey: .recordingID)
        try container.encode(schemaVersion.rawValue, forKey: .schemaVersion)
        try container.encode(terminalTick.rawValue, forKey: .terminalTick)
    }
}
