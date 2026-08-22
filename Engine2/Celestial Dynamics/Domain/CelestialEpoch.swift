/// Nonnegative time on one celestial-dynamics timeline.
///
/// The stored seconds are relative to the generated gravity system's reference
/// epoch. Wall time and Render cadence never participate in this value.
nonisolated struct CelestialEpoch: Equatable, Hashable, Sendable {
    static let zero = CelestialEpoch(secondsSinceReferenceEpoch: 0)

    let secondsSinceReferenceEpoch: Double

    init(secondsSinceReferenceEpoch: Double) {
        precondition(
            secondsSinceReferenceEpoch.isFinite && secondsSinceReferenceEpoch >= 0,
            "A celestial epoch must be finite and nonnegative."
        )
        self.secondsSinceReferenceEpoch = secondsSinceReferenceEpoch
    }

    /// Returns an epoch advanced by one nonnegative astronomical duration.
    ///
    /// Floating-point addition rounds the resulting epoch. The sum must remain
    /// finite, and a positive duration must advance to a distinct value.
    func advanced(by duration: AstronomicalDuration) -> CelestialEpoch {
        let advancedSeconds = secondsSinceReferenceEpoch + duration.seconds
        precondition(
            advancedSeconds.isFinite
                && (duration == .zero || advancedSeconds > secondsSinceReferenceEpoch),
            "A celestial epoch advance must remain finite and distinguishable."
        )
        return CelestialEpoch(secondsSinceReferenceEpoch: advancedSeconds)
    }

    /// Returns the nonnegative duration since an earlier epoch on this timeline.
    func duration(since earlierEpoch: CelestialEpoch) -> AstronomicalDuration {
        precondition(earlierEpoch <= self, "The earlier celestial epoch must not follow this epoch.")
        return AstronomicalDuration(
            seconds: secondsSinceReferenceEpoch - earlierEpoch.secondsSinceReferenceEpoch
        )
    }
}

extension CelestialEpoch: Codable {
    private enum CodingKeys: String, CodingKey {
        case secondsSinceReferenceEpoch
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let seconds = try container.decode(Double.self, forKey: .secondsSinceReferenceEpoch)
        guard seconds.isFinite, seconds >= 0 else {
            throw DecodingError.dataCorruptedError(
                forKey: .secondsSinceReferenceEpoch,
                in: container,
                debugDescription: "A celestial epoch must be finite and nonnegative."
            )
        }
        self.init(secondsSinceReferenceEpoch: seconds)
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(secondsSinceReferenceEpoch, forKey: .secondsSinceReferenceEpoch)
    }
}

extension CelestialEpoch: Comparable {
    nonisolated static func < (lhs: CelestialEpoch, rhs: CelestialEpoch) -> Bool {
        lhs.secondsSinceReferenceEpoch < rhs.secondsSinceReferenceEpoch
    }
}
