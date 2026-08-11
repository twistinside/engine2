/// Nonnegative astronomical mass stored in kilograms.
///
/// The shared base unit lets formation code conserve stellar, planetary, and
/// satellite mass without mixing unlabelled solar- and Earth-mass values.
nonisolated struct AstronomicalMass: Codable, Equatable, Hashable, Sendable {
    static let zero = AstronomicalMass(kilograms: 0)

    private static let kilogramsPerEarthMass = 5.9722e24
    private static let kilogramsPerSolarMass = 1.98847e30

    let kilograms: Double

    var earthMasses: Double {
        kilograms / Self.kilogramsPerEarthMass
    }

    var solarMasses: Double {
        kilograms / Self.kilogramsPerSolarMass
    }

    init(kilograms: Double) {
        precondition(
            kilograms.isFinite && kilograms >= 0,
            "Astronomical mass must be finite and nonnegative."
        )
        self.kilograms = kilograms
    }

    init(earthMasses: Double) {
        self.init(kilograms: earthMasses * Self.kilogramsPerEarthMass)
    }

    init(solarMasses: Double) {
        self.init(kilograms: solarMasses * Self.kilogramsPerSolarMass)
    }
}

extension AstronomicalMass: Comparable {
    nonisolated static func < (lhs: AstronomicalMass, rhs: AstronomicalMass) -> Bool {
        lhs.kilograms < rhs.kilograms
    }
}
