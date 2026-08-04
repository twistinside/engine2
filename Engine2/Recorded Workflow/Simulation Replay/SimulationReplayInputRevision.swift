/// Persistence-owned representation of one Input publication revision.
nonisolated struct SimulationReplayInputRevision: Equatable, Sendable {
    let session: UInt64
    let sequence: UInt64

    var inputRevision: InputRevision {
        InputRevision(session: session, sequence: sequence)
    }

    init(session: UInt64, sequence: UInt64) {
        self.session = session
        self.sequence = sequence
    }

    init(recording revision: InputRevision) {
        self.init(session: revision.session, sequence: revision.sequence)
    }
}

extension SimulationReplayInputRevision: Codable {
    private enum CodingKeys: String, CodingKey {
        case session
        case sequence
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            session: try container.decode(UInt64.self, forKey: .session),
            sequence: try container.decode(UInt64.self, forKey: .sequence)
        )
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(session, forKey: .session)
        try container.encode(sequence, forKey: .sequence)
    }
}
