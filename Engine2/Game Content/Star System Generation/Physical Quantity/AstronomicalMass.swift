/// Nonnegative astronomical mass stored in kilograms.
///
/// The shared base unit lets formation code conserve stellar, planetary, and
/// satellite mass without mixing unlabelled solar- and Earth-mass values.
nonisolated struct AstronomicalMass: Codable, Equatable, Hashable, Sendable {
    static let zero = AstronomicalMass(kilograms: 0)
    static let earth = AstronomicalMass(kilograms: 5.9722e24)
    static let sun = AstronomicalMass(kilograms: 1.98847e30)

    let kilograms: Double

    var earthMasses: Double {
        kilograms / Self.earth.kilograms
    }

    var solarMasses: Double {
        kilograms / Self.sun.kilograms
    }

    init(kilograms: Double) {
        precondition(
            kilograms.isFinite && kilograms >= 0,
            "Astronomical mass must be finite and nonnegative."
        )
        self.kilograms = kilograms
    }

    init(earthMasses: Double) {
        self.init(kilograms: earthMasses * Self.earth.kilograms)
    }

    init(solarMasses: Double) {
        self.init(kilograms: solarMasses * Self.sun.kilograms)
    }
}

extension AstronomicalMass: Comparable {
    nonisolated static func < (lhs: AstronomicalMass, rhs: AstronomicalMass) -> Bool {
        lhs.kilograms < rhs.kilograms
    }
}
