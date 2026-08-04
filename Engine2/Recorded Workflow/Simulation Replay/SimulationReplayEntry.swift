/// One exact Input assignment consumed while producing a recorded Simulation tick.
///
/// Tick zero cannot consume an assignment because it describes the constructed
/// world before the first fixed step.
nonisolated struct SimulationReplayEntry: Equatable, Sendable {
    let tick: SimulationTick
    let inputAssignment: SimulationReplayInputAssignment

    init(
        tick: SimulationTick,
        inputAssignment: SimulationReplayInputAssignment
    ) throws(SimulationReplayError) {
        guard tick > .zero else {
            throw .inputEntryTickIsZero
        }

        self.tick = tick
        self.inputAssignment = inputAssignment
    }
}

extension SimulationReplayEntry: Codable {
    private enum CodingKeys: String, CodingKey {
        case inputAssignment
        case tick
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        do {
            try self.init(
                tick: SimulationTick(
                    rawValue: container.decode(
                        UInt64.self,
                        forKey: .tick
                    )
                ),
                inputAssignment: container.decode(
                    SimulationReplayInputAssignment.self,
                    forKey: .inputAssignment
                )
            )
        } catch let error as SimulationReplayError {
            throw DecodingError.dataCorruptedError(
                forKey: .tick,
                in: container,
                debugDescription: error.description
            )
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(inputAssignment, forKey: .inputAssignment)
        try container.encode(tick.rawValue, forKey: .tick)
    }
}
