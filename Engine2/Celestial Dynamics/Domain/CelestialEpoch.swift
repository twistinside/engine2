/// Nonnegative time on one celestial-dynamics timeline.
///
/// The stored seconds are relative to the generated gravity system's reference
/// epoch. Wall time and Render cadence never participate in this value.
nonisolated struct CelestialEpoch: Codable, Equatable, Hashable, Sendable {
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
    func advanced(by duration: AstronomicalDuration) -> CelestialEpoch {
        CelestialEpoch(
            secondsSinceReferenceEpoch: secondsSinceReferenceEpoch + duration.seconds
        )
    }

    /// Returns the nonnegative duration since an earlier epoch on this timeline.
    func duration(since earlierEpoch: CelestialEpoch) -> AstronomicalDuration {
        precondition(earlierEpoch <= self, "The earlier celestial epoch must not follow this epoch.")
        return AstronomicalDuration(
            seconds: secondsSinceReferenceEpoch - earlierEpoch.secondsSinceReferenceEpoch
        )
    }
}

extension CelestialEpoch: Comparable {
    nonisolated static func < (lhs: CelestialEpoch, rhs: CelestialEpoch) -> Bool {
        lhs.secondsSinceReferenceEpoch < rhs.secondsSinceReferenceEpoch
    }
}
