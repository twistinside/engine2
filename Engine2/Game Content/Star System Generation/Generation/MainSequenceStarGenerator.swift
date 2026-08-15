import Foundation

/// Generates one analytic main-sequence star from the versioned stellar substream.
///
/// The current mass-luminosity and activity relations are explicit V1 proxies.
/// A later model version can replace them with bundled stellar-track tables
/// without changing the resolved output boundary.
nonisolated struct MainSequenceStarGenerator: Sendable {
    let policy: StarSystemGenerationPolicy

    func generate(seed: StarSystemSeed) -> GeneratedStar {
        var random = StarSystemRandomStream(
            seed: seed,
            modelVersion: policy.modelVersion,
            domain: .star
        )
        let massSolar = random.powerLaw(
            in: policy.minimumStellarMassSolar...policy.maximumStellarMassSolar,
            exponent: 2.3
        )
        let metallicityDex = clamped(
            random.normal(
                mean: policy.metallicityMeanDex,
                standardDeviation: policy.metallicityStandardDeviationDex
            ),
            to: policy.minimumMetallicityDex...policy.maximumMetallicityDex
        )
        let nominalLuminosity = pow(massSolar, 3.8) * pow(10, -0.12 * metallicityDex)
        let mainSequenceLifetimeGigayears = 10 * massSolar / nominalLuminosity
        let maximumAge = max(
            policy.minimumSystemAgeGigayears,
            min(policy.maximumSystemAgeGigayears, 0.9 * mainSequenceLifetimeGigayears)
        )
        let ageGigayears = random.uniform(in: policy.minimumSystemAgeGigayears...maximumAge)
        let ageFraction = min(ageGigayears / mainSequenceLifetimeGigayears, 0.9)
        let luminositySolar = nominalLuminosity * (0.7 + 0.65 * ageFraction)
        let radiusSolar = pow(massSolar, 0.8) * (0.87 + 0.28 * ageFraction)
        let effectiveTemperatureKelvin = 5_772 * pow(luminositySolar / (radiusSolar * radiusSolar), 0.25)
        let activityRegime = StellarActivityRegime.allCases[random.integer(in: 0...2)]
        let activityMultiplier = activityMultiplier(for: activityRegime)
        let xuvFraction = max(
            1e-7,
            min(1e-3, 1e-3 * activityMultiplier * pow(max(ageGigayears / 0.1, 1), -1.2))
        )

        return GeneratedStar(
            mass: AstronomicalMass(solarMasses: massSolar),
            metallicityDex: metallicityDex,
            age: AstronomicalDuration(gigayears: ageGigayears),
            luminosity: StellarLuminosity(solarLuminosities: luminositySolar),
            radius: AstronomicalDistance(solarRadii: radiusSolar),
            effectiveTemperature: ThermodynamicTemperature(kelvin: effectiveTemperatureKelvin),
            activityRegime: activityRegime,
            xuvLuminosityFraction: xuvFraction
        )
    }

    private func activityMultiplier(for regime: StellarActivityRegime) -> Double {
        switch regime {
        case .slow:
            0.5
        case .median:
            1
        case .fast:
            2
        }
    }

    private func clamped(_ value: Double, to range: ClosedRange<Double>) -> Double {
        min(max(value, range.lowerBound), range.upperBound)
    }
}
