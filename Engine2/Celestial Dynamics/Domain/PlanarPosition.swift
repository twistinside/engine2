import simd

/// Finite position in the shared two-dimensional orbital plane.
///
/// Physics stores meters in `Double`. Presentation code may project this value
/// into a three-dimensional Render coordinate system without feeding that
/// projection back into Simulation.
nonisolated struct PlanarPosition: Equatable, Sendable {
    static let zero = PlanarPosition(meters: .zero)

    let meters: SIMD2<Double>

    init(meters: SIMD2<Double>) {
        precondition(meters.isFinite, "A planar position must contain finite meters.")
        self.meters = meters
    }

}

extension PlanarPosition: Codable {
    private enum CodingKeys: String, CodingKey {
        case meters
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let meters = try container.decode(SIMD2<Double>.self, forKey: .meters)
        guard meters.isFinite else {
            throw DecodingError.dataCorruptedError(
                forKey: .meters,
                in: container,
                debugDescription: "A planar position must contain finite meters."
            )
        }
        self.init(meters: meters)
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(meters, forKey: .meters)
    }
}
