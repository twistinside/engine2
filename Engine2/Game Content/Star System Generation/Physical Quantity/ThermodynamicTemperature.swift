/// Nonnegative thermodynamic temperature stored in kelvin.
nonisolated struct ThermodynamicTemperature: Codable, Equatable, Hashable, Sendable {
    static let absoluteZero = ThermodynamicTemperature(kelvin: 0)

    let kelvin: Double

    init(kelvin: Double) {
        precondition(
            kelvin.isFinite && kelvin >= 0,
            "Thermodynamic temperature must be finite and nonnegative."
        )
        self.kelvin = kelvin
    }
}

extension ThermodynamicTemperature: Comparable {
    nonisolated static func < (lhs: ThermodynamicTemperature, rhs: ThermodynamicTemperature) -> Bool {
        lhs.kelvin < rhs.kelvin
    }
}
