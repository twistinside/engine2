import simd

/// Finite acceleration in the shared two-dimensional orbital plane.
nonisolated struct PlanarAcceleration: Equatable, Sendable {
    static let zero = PlanarAcceleration(metersPerSecondSquared: .zero)

    let metersPerSecondSquared: SIMD2<Double>

    init(metersPerSecondSquared: SIMD2<Double>) {
        precondition(
            metersPerSecondSquared.isFinite,
            "A planar acceleration must contain finite meters per second squared."
        )
        self.metersPerSecondSquared = metersPerSecondSquared
    }
}

extension PlanarAcceleration: Codable {
    private enum CodingKeys: String, CodingKey {
        case metersPerSecondSquared
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let acceleration = try container.decode(SIMD2<Double>.self, forKey: .metersPerSecondSquared)
        guard acceleration.isFinite else {
            throw DecodingError.dataCorruptedError(
                forKey: .metersPerSecondSquared,
                in: container,
                debugDescription: "A planar acceleration must contain finite meters per second squared."
            )
        }
        self.init(metersPerSecondSquared: acceleration)
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(metersPerSecondSquared, forKey: .metersPerSecondSquared)
    }
}
