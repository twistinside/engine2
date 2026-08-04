import simd

/// Stable two-lane floating-point record used by the Simulation replay schema.
///
/// Construction rejects nonfinite values before they can become cumulative
/// Input state and poison every later tick in the replay.
nonisolated struct SimulationReplayVector2: Equatable, Sendable {
    let x: Float
    let y: Float

    var inputValue: SIMD2<Float> {
        SIMD2<Float>(x, y)
    }

    init(x: Float, y: Float) throws(SimulationReplayError) {
        let value = SIMD2<Float>(x, y)
        guard value.isFinite else {
            throw .nonfiniteInputVector
        }

        self.x = x
        self.y = y
    }

    init(recording value: SIMD2<Float>) throws(SimulationReplayError) {
        try self.init(x: value.x, y: value.y)
    }
}

extension SimulationReplayVector2: Codable {
    private enum CodingKeys: String, CodingKey {
        case x
        case y
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let x = try container.decode(Float.self, forKey: .x)
        let y = try container.decode(Float.self, forKey: .y)

        do {
            try self.init(x: x, y: y)
        } catch {
            throw DecodingError.dataCorruptedError(
                forKey: .x,
                in: container,
                debugDescription: error.description
            )
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(x, forKey: .x)
        try container.encode(y, forKey: .y)
    }
}
