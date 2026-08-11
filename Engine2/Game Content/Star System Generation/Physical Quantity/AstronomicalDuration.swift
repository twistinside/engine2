/// Nonnegative duration used by the formation and stellar-evolution model.
///
/// Seconds are the serialized base unit. Megayear and gigayear projections
/// keep short disk evolution distinct from long present-day evolution.
nonisolated struct AstronomicalDuration: Codable, Equatable, Hashable, Sendable {
    static let zero = AstronomicalDuration(seconds: 0)
    static let year = AstronomicalDuration(seconds: 31_557_600.0)

    let seconds: Double

    var megayears: Double {
        seconds / (Self.year.seconds * 1_000_000)
    }

    var gigayears: Double {
        seconds / (Self.year.seconds * 1_000_000_000)
    }

    init(seconds: Double) {
        precondition(
            seconds.isFinite && seconds >= 0,
            "Astronomical duration must be finite and nonnegative."
        )
        self.seconds = seconds
    }

    init(megayears: Double) {
        self.init(seconds: megayears * Self.year.seconds * 1_000_000)
    }

    init(gigayears: Double) {
        self.init(seconds: gigayears * Self.year.seconds * 1_000_000_000)
    }
}

extension AstronomicalDuration: Comparable {
    nonisolated static func < (lhs: AstronomicalDuration, rhs: AstronomicalDuration) -> Bool {
        lhs.seconds < rhs.seconds
    }
}
