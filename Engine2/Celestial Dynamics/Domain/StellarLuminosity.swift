/// Nonnegative stellar bolometric luminosity stored in watts.
nonisolated struct StellarLuminosity: Codable, Equatable, Hashable, Sendable {
    static let zero = StellarLuminosity(watts: 0)
    static let solarLuminosity = StellarLuminosity(watts: 3.828e26)

    let watts: Double

    var solarLuminosities: Double {
        watts / Self.solarLuminosity.watts
    }

    init(watts: Double) {
        precondition(
            watts.isFinite && watts >= 0,
            "Stellar luminosity must be finite and nonnegative."
        )
        self.watts = watts
    }

    init(solarLuminosities: Double) {
        self.init(watts: solarLuminosities * Self.solarLuminosity.watts)
    }
}
