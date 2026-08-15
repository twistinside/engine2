import Foundation

/// Version-one tapered disk geometry and its shared gravitational-stability calculation.
///
/// Disk construction and verification consume this value so the modeled edge,
/// represented mass fraction, annulus weights, and Toomre-Q equation remain one
/// calibration rule.
nonisolated struct ProtoplanetaryDiskProfile: Sendable {
    static let minimumSupportedToomreQ = 1.4

    private static let astronomicalUnitMeters = 149_597_870_700.0
    private static let boltzmannConstant = 1.380_649e-23
    private static let gravitationalConstant = 6.674_30e-11
    private static let maximumModeledRadiusAU = 150.0
    private static let meanMolecularWeight = 2.34
    private static let protonMassKilograms = 1.672_621_923_69e-27

    let characteristicRadiusAU: Double
    let surfaceDensityExponent: Double
    let innerEdgeAU: Double
    let annulusCount: Int

    var outerEdgeAU: Double {
        max(
            innerEdgeAU * 4,
            min(Self.maximumModeledRadiusAU, 5 * characteristicRadiusAU)
        )
    }

    var representedMassFraction: Double {
        let taperPower = 2 - surfaceDensityExponent
        let innerScaledPower = pow(innerEdgeAU / characteristicRadiusAU, taperPower)
        let outerScaledPower = pow(outerEdgeAU / characteristicRadiusAU, taperPower)
        return exp(-innerScaledPower) - exp(-outerScaledPower)
    }

    var radialEdges: [Double] {
        let logarithmicStep = log(outerEdgeAU / innerEdgeAU) / Double(annulusCount)
        return (0...annulusCount).map { index in
            innerEdgeAU * exp(Double(index) * logarithmicStep)
        }
    }

    var normalizedAnnulusWeights: [Double] {
        let edges = radialEdges
        let weights = (0..<(edges.count - 1)).map { index in
            let inner = edges[index]
            let outer = edges[index + 1]
            let center = sqrt(inner * outer)
            let scaledRadius = center / characteristicRadiusAU
            let surfaceDensity = pow(scaledRadius, -surfaceDensityExponent)
                * exp(-pow(scaledRadius, 2 - surfaceDensityExponent))
            return 2 * Double.pi * center * (outer - inner) * surfaceDensity
        }
        let total = weights.reduce(0, +)
        precondition(
            total.isFinite && total > 0,
            "Disk annulus weights must have a positive finite sum."
        )
        return weights.map { $0 / total }
    }

    func maximumStableDiskMassRatio(around star: GeneratedStar) -> Double {
        let massFractions = normalizedAnnulusWeights.map {
            $0 * representedMassFraction
        }
        let minimumQAtUnitDiskRatio = minimumToomreQ(
            totalGasMassKilograms: star.mass.kilograms,
            annulusMassFractions: massFractions,
            around: star
        )
        return minimumQAtUnitDiskRatio / Self.minimumSupportedToomreQ
    }

    func minimumToomreQ(
        gasMass: AstronomicalMass,
        around star: GeneratedStar
    ) -> Double {
        minimumToomreQ(
            totalGasMassKilograms: gasMass.kilograms,
            annulusMassFractions: normalizedAnnulusWeights,
            around: star
        )
    }

    private func minimumToomreQ(
        totalGasMassKilograms: Double,
        annulusMassFractions: [Double],
        around star: GeneratedStar
    ) -> Double {
        let edges = radialEdges
        var minimumQ = Double.greatestFiniteMagnitude
        for index in annulusMassFractions.indices {
            let innerRadiusMeters = edges[index] * Self.astronomicalUnitMeters
            let outerRadiusMeters = edges[index + 1] * Self.astronomicalUnitMeters
            let centerRadiusMeters = sqrt(innerRadiusMeters * outerRadiusMeters)
            let centerRadiusAU = sqrt(edges[index] * edges[index + 1])
            let temperatureKelvin = max(
                10,
                280
                    * pow(max(star.luminosity.solarLuminosities, 1e-6), 0.25)
                    / sqrt(centerRadiusAU)
            )
            let soundSpeedMetersPerSecond = sqrt(
                Self.boltzmannConstant * temperatureKelvin
                    / (Self.meanMolecularWeight * Self.protonMassKilograms)
            )
            let angularFrequencyPerSecond = sqrt(
                Self.gravitationalConstant * star.mass.kilograms
                    / pow(centerRadiusMeters, 3)
            )
            let annulusAreaSquareMeters = Double.pi
                * (
                    outerRadiusMeters * outerRadiusMeters
                        - innerRadiusMeters * innerRadiusMeters
                )
            let surfaceDensityKilogramsPerSquareMeter = totalGasMassKilograms
                * annulusMassFractions[index]
                / annulusAreaSquareMeters
            let toomreQ = soundSpeedMetersPerSecond * angularFrequencyPerSecond
                / (Double.pi * Self.gravitationalConstant * surfaceDensityKilogramsPerSquareMeter)
            minimumQ = min(minimumQ, toomreQ)
        }
        return minimumQ
    }
}
