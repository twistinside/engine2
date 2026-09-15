/// A finite, nonnegative amount of health or damage carried by Simulation component values.
///
/// Zero represents exhausted health. Components that require a positive initial amount validate
/// that restriction at their construction boundary.
nonisolated struct HitPoints: Equatable, Sendable {
    static let zero = HitPoints(rawValue: 0)

    let rawValue: Double

    init(rawValue: Double) {
        precondition(rawValue.isFinite && rawValue >= 0, "Hit points must be finite and nonnegative.")
        self.rawValue = rawValue
    }
}

extension HitPoints: Codable {
    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let rawValue = try values.decode(Double.self, forKey: .rawValue)
        guard rawValue.isFinite, rawValue >= 0 else {
            throw DecodingError.dataCorruptedError(
                forKey: .rawValue,
                in: values,
                debugDescription: "Hit points must be finite and nonnegative."
            )
        }
        self.rawValue = rawValue
    }
}
