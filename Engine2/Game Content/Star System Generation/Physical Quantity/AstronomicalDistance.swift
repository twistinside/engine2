/// Nonnegative astronomical distance stored in meters.
///
/// Generation uses this value for stellar radii, planetary radii, stellar
/// orbits, and satellite orbits. Named projections make the unit explicit at
/// every calculation boundary.
nonisolated struct AstronomicalDistance: Codable, Comparable, Equatable, Hashable, Sendable {
    static let zero = AstronomicalDistance(meters: 0)
    static let astronomicalUnit = AstronomicalDistance(meters: 149_597_870_700.0)
    static let earthRadius = AstronomicalDistance(meters: 6_371_000.0)
    static let solarRadius = AstronomicalDistance(meters: 695_700_000.0)

    let meters: Double

    var astronomicalUnits: Double {
        meters / Self.astronomicalUnit.meters
    }

    var earthRadii: Double {
        meters / Self.earthRadius.meters
    }

    var solarRadii: Double {
        meters / Self.solarRadius.meters
    }

    init(meters: Double) {
        precondition(
            meters.isFinite && meters >= 0,
            "Astronomical distance must be finite and nonnegative."
        )
        self.meters = meters
    }

    init(astronomicalUnits: Double) {
        self.init(meters: astronomicalUnits * Self.astronomicalUnit.meters)
    }

    init(earthRadii: Double) {
        self.init(meters: earthRadii * Self.earthRadius.meters)
    }

    init(solarRadii: Double) {
        self.init(meters: solarRadii * Self.solarRadius.meters)
    }

    static func < (lhs: AstronomicalDistance, rhs: AstronomicalDistance) -> Bool {
        lhs.meters < rhs.meters
    }
}
