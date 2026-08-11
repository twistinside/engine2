/// Nonnegative astronomical distance stored in meters.
///
/// Generation uses this value for stellar radii, planetary radii, stellar
/// orbits, and satellite orbits. Named projections make the unit explicit at
/// every calculation boundary.
nonisolated struct AstronomicalDistance: Codable, Comparable, Equatable, Hashable, Sendable {
    static let zero = AstronomicalDistance(meters: 0)

    private static let metersPerAstronomicalUnit = 149_597_870_700.0
    private static let metersPerEarthRadius = 6_371_000.0
    private static let metersPerSolarRadius = 695_700_000.0

    let meters: Double

    var astronomicalUnits: Double {
        meters / Self.metersPerAstronomicalUnit
    }

    var earthRadii: Double {
        meters / Self.metersPerEarthRadius
    }

    var solarRadii: Double {
        meters / Self.metersPerSolarRadius
    }

    init(meters: Double) {
        precondition(Self.accepts(meters), "Astronomical distance must be finite and nonnegative.")
        self.meters = meters
    }

    init(astronomicalUnits: Double) {
        self.init(meters: astronomicalUnits * Self.metersPerAstronomicalUnit)
    }

    init(earthRadii: Double) {
        self.init(meters: earthRadii * Self.metersPerEarthRadius)
    }

    init(solarRadii: Double) {
        self.init(meters: solarRadii * Self.metersPerSolarRadius)
    }

    static func accepts(_ meters: Double) -> Bool {
        meters.isFinite && meters >= 0
    }

    static func < (lhs: AstronomicalDistance, rhs: AstronomicalDistance) -> Bool {
        lhs.meters < rhs.meters
    }
}
