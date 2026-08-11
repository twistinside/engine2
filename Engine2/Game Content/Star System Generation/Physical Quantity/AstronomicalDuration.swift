/// Nonnegative duration used by the formation and stellar-evolution model.
///
/// Seconds are the serialized base unit. Megayear and gigayear projections
/// keep short disk evolution distinct from long present-day evolution.
nonisolated struct AstronomicalDuration: Codable, Comparable, Equatable, Hashable, Sendable {
    static let zero = AstronomicalDuration(seconds: 0)

    private static let secondsPerYear = 31_557_600.0

    let seconds: Double

    var megayears: Double {
        seconds / (Self.secondsPerYear * 1_000_000)
    }

    var gigayears: Double {
        seconds / (Self.secondsPerYear * 1_000_000_000)
    }

    init(seconds: Double) {
        precondition(
            seconds.isFinite && seconds >= 0,
            "Astronomical duration must be finite and nonnegative."
        )
        self.seconds = seconds
    }

    init(megayears: Double) {
        self.init(seconds: megayears * Self.secondsPerYear * 1_000_000)
    }

    init(gigayears: Double) {
        self.init(seconds: gigayears * Self.secondsPerYear * 1_000_000_000)
    }

    static func < (lhs: AstronomicalDuration, rhs: AstronomicalDuration) -> Bool {
        lhs.seconds < rhs.seconds
    }
}
