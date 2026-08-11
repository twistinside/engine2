/// Nonnegative thermodynamic temperature stored in kelvin.
nonisolated struct ThermodynamicTemperature: Codable, Comparable, Equatable, Hashable, Sendable {
    static let absoluteZero = ThermodynamicTemperature(kelvin: 0)

    let kelvin: Double

    init(kelvin: Double) {
        precondition(Self.accepts(kelvin), "Thermodynamic temperature must be finite and nonnegative.")
        self.kelvin = kelvin
    }

    static func accepts(_ kelvin: Double) -> Bool {
        kelvin.isFinite && kelvin >= 0
    }

    static func < (lhs: ThermodynamicTemperature, rhs: ThermodynamicTemperature) -> Bool {
        lhs.kelvin < rhs.kelvin
    }
}
