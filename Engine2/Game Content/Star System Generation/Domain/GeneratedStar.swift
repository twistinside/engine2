/// Resolved present-day properties and retained early-activity history of one star.
///
/// The first generation model supports exactly one main-sequence star. Its
/// luminosity, radius, and effective temperature are analytic approximations
/// selected by the stored model version.
nonisolated struct GeneratedStar: Codable, Equatable, Sendable {
    let mass: AstronomicalMass
    let metallicityDex: Double
    let age: AstronomicalDuration
    let luminosity: StellarLuminosity
    let radius: AstronomicalDistance
    let effectiveTemperature: ThermodynamicTemperature
    let activityRegime: StellarActivityRegime

    /// Present XUV-to-bolometric luminosity fraction used by atmosphere evolution.
    let xuvLuminosityFraction: Double
}
