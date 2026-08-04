/// Canonical durable representation of one nonempty Simulation Input assignment.
///
/// A missing entry represents `.none`, so the persisted enum includes only the
/// assignments that change a Simulation consumer's Input treatment.
nonisolated enum SimulationReplayInputAssignment: Equatable, Sendable {
    case ingest(SimulationReplayInputSnapshot)
    case rebase(SimulationReplayInputSnapshot)
    case rebaseThenIngest(
        baseline: SimulationReplayInputSnapshot,
        snapshot: SimulationReplayInputSnapshot
    )

    var inputAssignment: SimulationInputAssignment {
        switch self {
        case let .ingest(snapshot):
            .ingest(snapshot.inputSnapshot)
        case let .rebase(snapshot):
            .rebase(snapshot.inputSnapshot)
        case let .rebaseThenIngest(baseline, snapshot):
            .rebaseThenIngest(
                baseline: baseline.inputSnapshot,
                snapshot: snapshot.inputSnapshot
            )
        }
    }

    init(recording assignment: SimulationInputAssignment) throws(SimulationReplayError) {
        self = switch assignment {
        case .none:
            throw SimulationReplayError.noneInputAssignmentRequiresGap
        case let .ingest(snapshot):
            .ingest(
                try SimulationReplayInputSnapshot(recording: snapshot)
            )
        case let .rebase(snapshot):
            .rebase(
                try SimulationReplayInputSnapshot(recording: snapshot)
            )
        case let .rebaseThenIngest(baseline, snapshot):
            .rebaseThenIngest(
                baseline: try SimulationReplayInputSnapshot(
                    recording: baseline
                ),
                snapshot: try SimulationReplayInputSnapshot(
                    recording: snapshot
                )
            )
        }
    }
}

extension SimulationReplayInputAssignment: Codable {
    private enum CodingKeys: String, CodingKey {
        case baseline
        case kind
        case snapshot
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)

        self = switch kind {
        case .ingest:
            .ingest(
                try container.decode(
                    SimulationReplayInputSnapshot.self,
                    forKey: .snapshot
                )
            )
        case .rebase:
            .rebase(
                try container.decode(
                    SimulationReplayInputSnapshot.self,
                    forKey: .snapshot
                )
            )
        case .rebaseThenIngest:
            .rebaseThenIngest(
                baseline: try container.decode(
                    SimulationReplayInputSnapshot.self,
                    forKey: .baseline
                ),
                snapshot: try container.decode(
                    SimulationReplayInputSnapshot.self,
                    forKey: .snapshot
                )
            )
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case let .ingest(snapshot):
            try container.encode(Kind.ingest, forKey: .kind)
            try container.encode(snapshot, forKey: .snapshot)

        case let .rebase(snapshot):
            try container.encode(Kind.rebase, forKey: .kind)
            try container.encode(snapshot, forKey: .snapshot)

        case let .rebaseThenIngest(baseline, snapshot):
            try container.encode(Kind.rebaseThenIngest, forKey: .kind)
            try container.encode(baseline, forKey: .baseline)
            try container.encode(snapshot, forKey: .snapshot)
        }
    }

    private enum Kind: String, Codable {
        case ingest
        case rebase
        case rebaseThenIngest
    }
}
