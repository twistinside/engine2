import simd

/// Finite velocity in the shared two-dimensional orbital plane.
nonisolated struct PlanarVelocity: Equatable, Sendable {
    static let zero = PlanarVelocity(metersPerSecond: .zero)

    let metersPerSecond: SIMD2<Double>

    init(metersPerSecond: SIMD2<Double>) {
        precondition(metersPerSecond.isFinite, "A planar velocity must contain finite meters per second.")
        self.metersPerSecond = metersPerSecond
    }

    /// Returns the velocity produced by composing one parent-relative velocity.
    func adding(_ relativeVelocity: PlanarVelocity) -> PlanarVelocity {
        PlanarVelocity(metersPerSecond: metersPerSecond + relativeVelocity.metersPerSecond)
    }
}

extension PlanarVelocity: Codable {
    private enum CodingKeys: String, CodingKey {
        case metersPerSecond
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let velocity = try container.decode(SIMD2<Double>.self, forKey: .metersPerSecond)
        guard velocity.isFinite else {
            throw DecodingError.dataCorruptedError(
                forKey: .metersPerSecond,
                in: container,
                debugDescription: "A planar velocity must contain finite meters per second."
            )
        }
        self.init(metersPerSecond: velocity)
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(metersPerSecond, forKey: .metersPerSecond)
    }
}
