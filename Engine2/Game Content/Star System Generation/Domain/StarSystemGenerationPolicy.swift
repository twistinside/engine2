/// Versioned calibration and bounded-work policy for physical system generation.
///
/// Values in this type are model calibration, not mutable gameplay knobs or
/// fundamental constants. The complete policy is persisted with each resolved
/// system so later audits can reproduce its construction inputs.
nonisolated struct StarSystemGenerationPolicy: Codable, Equatable, Sendable {
    private static let maximumAnnulusCount = 512
    private static let maximumEmbryoLimit = 256
    private static let maximumFormationStepCount = 512
    private static let maximumEvolutionStepCount = 512
    private static let maximumMoonLimit = 16

    /// Initial calibration for the bounded core-accretion-lite model.
    static let coreAccretionLiteV1 = StarSystemGenerationPolicy(
        modelVersion: .coreAccretionLiteV1,
        minimumStellarMassSolar: 0.5,
        maximumStellarMassSolar: 1.2,
        metallicityMeanDex: -0.05,
        metallicityStandardDeviationDex: 0.20,
        minimumMetallicityDex: -0.5,
        maximumMetallicityDex: 0.5,
        minimumSystemAgeGigayears: 0.5,
        maximumSystemAgeGigayears: 10,
        medianDiskMassRatio: 0.02,
        diskMassScatterDex: 0.5,
        minimumDiskMassRatio: 0.003,
        maximumDiskMassRatio: 0.20,
        medianDiskLifetimeMegayears: 3,
        diskLifetimeScatterDex: 0.25,
        minimumDiskLifetimeMegayears: 1,
        maximumDiskLifetimeMegayears: 10,
        medianCharacteristicRadiusAU: 30,
        characteristicRadiusScatterDex: 0.25,
        baseSolidFraction: 0.014,
        annulusCount: 128,
        maximumEmbryoCount: 64,
        formationStepCount: 96,
        evolutionStepCount: 48,
        embryoSeedMassEarth: 0.01,
        solidAccretionEfficiency: 0.45,
        gasAccretionEfficiency: 0.60,
        migrationEfficiency: 0.18,
        formationMergerSpacing: 3.5,
        radialClearanceHillRadii: 3.5,
        finalPlanetSpacing: 12,
        finalGiantPlanetSpacing: 15,
        giantMassThresholdEarth: 30,
        atmosphereEscapeEfficiency: 0.10,
        maximumMoonCountPerPlanet: 4
    )

    let modelVersion: StarSystemGenerationModelVersion
    let minimumStellarMassSolar: Double
    let maximumStellarMassSolar: Double
    let metallicityMeanDex: Double
    let metallicityStandardDeviationDex: Double
    let minimumMetallicityDex: Double
    let maximumMetallicityDex: Double
    let minimumSystemAgeGigayears: Double
    let maximumSystemAgeGigayears: Double
    let medianDiskMassRatio: Double
    let diskMassScatterDex: Double
    let minimumDiskMassRatio: Double
    let maximumDiskMassRatio: Double
    let medianDiskLifetimeMegayears: Double
    let diskLifetimeScatterDex: Double
    let minimumDiskLifetimeMegayears: Double
    let maximumDiskLifetimeMegayears: Double
    let medianCharacteristicRadiusAU: Double
    let characteristicRadiusScatterDex: Double
    let baseSolidFraction: Double
    let annulusCount: Int
    let maximumEmbryoCount: Int
    let formationStepCount: Int
    let evolutionStepCount: Int
    let embryoSeedMassEarth: Double
    let solidAccretionEfficiency: Double
    let gasAccretionEfficiency: Double
    let migrationEfficiency: Double
    let formationMergerSpacing: Double
    let radialClearanceHillRadii: Double
    let finalPlanetSpacing: Double
    let finalGiantPlanetSpacing: Double
    let giantMassThresholdEarth: Double
    let atmosphereEscapeEfficiency: Double
    let maximumMoonCountPerPlanet: Int

    /// Whether policy values satisfy the shared trusted-construction and decoded admission contract.
    var isValid: Bool {
        Self.isPositiveFinite(minimumStellarMassSolar)
            && maximumStellarMassSolar.isFinite
            && maximumStellarMassSolar >= minimumStellarMassSolar
            && metallicityMeanDex.isFinite
            && Self.isNonnegativeFinite(metallicityStandardDeviationDex)
            && minimumMetallicityDex.isFinite
            && maximumMetallicityDex.isFinite
            && maximumMetallicityDex >= minimumMetallicityDex
            && Self.isPositiveFinite(minimumSystemAgeGigayears)
            && maximumSystemAgeGigayears.isFinite
            && maximumSystemAgeGigayears >= minimumSystemAgeGigayears
            && Self.isPositiveFinite(medianDiskMassRatio)
            && Self.isNonnegativeFinite(diskMassScatterDex)
            && Self.isPositiveFinite(minimumDiskMassRatio)
            && maximumDiskMassRatio.isFinite
            && maximumDiskMassRatio >= minimumDiskMassRatio
            && Self.isPositiveFinite(medianDiskLifetimeMegayears)
            && Self.isNonnegativeFinite(diskLifetimeScatterDex)
            && Self.isPositiveFinite(minimumDiskLifetimeMegayears)
            && maximumDiskLifetimeMegayears.isFinite
            && maximumDiskLifetimeMegayears >= minimumDiskLifetimeMegayears
            && Self.isPositiveFinite(medianCharacteristicRadiusAU)
            && Self.isNonnegativeFinite(characteristicRadiusScatterDex)
            && Self.isPositiveFinite(baseSolidFraction)
            && (8...Self.maximumAnnulusCount).contains(annulusCount)
            && (1...Self.maximumEmbryoLimit).contains(maximumEmbryoCount)
            && (1...Self.maximumFormationStepCount).contains(formationStepCount)
            && (1...Self.maximumEvolutionStepCount).contains(evolutionStepCount)
            && Self.isPositiveFinite(embryoSeedMassEarth)
            && Self.isNonnegativeFinite(solidAccretionEfficiency)
            && Self.isNonnegativeFinite(gasAccretionEfficiency)
            && Self.isNonnegativeFinite(migrationEfficiency)
            && Self.isPositiveFinite(formationMergerSpacing)
            && Self.isPositiveFinite(radialClearanceHillRadii)
            && finalPlanetSpacing.isFinite
            && finalPlanetSpacing >= formationMergerSpacing
            && finalGiantPlanetSpacing.isFinite
            && finalGiantPlanetSpacing >= finalPlanetSpacing
            && Self.isPositiveFinite(giantMassThresholdEarth)
            && Self.acceptsUnitFactor(atmosphereEscapeEfficiency)
            && (0...Self.maximumMoonLimit).contains(maximumMoonCountPerPlanet)
    }

    /// Whether every calibration value matches the stored model version.
    var isSupportedCalibration: Bool {
        switch modelVersion {
        case .coreAccretionLiteV1:
            self == .coreAccretionLiteV1
        }
    }

    init(
        modelVersion: StarSystemGenerationModelVersion,
        minimumStellarMassSolar: Double,
        maximumStellarMassSolar: Double,
        metallicityMeanDex: Double,
        metallicityStandardDeviationDex: Double,
        minimumMetallicityDex: Double,
        maximumMetallicityDex: Double,
        minimumSystemAgeGigayears: Double,
        maximumSystemAgeGigayears: Double,
        medianDiskMassRatio: Double,
        diskMassScatterDex: Double,
        minimumDiskMassRatio: Double,
        maximumDiskMassRatio: Double,
        medianDiskLifetimeMegayears: Double,
        diskLifetimeScatterDex: Double,
        minimumDiskLifetimeMegayears: Double,
        maximumDiskLifetimeMegayears: Double,
        medianCharacteristicRadiusAU: Double,
        characteristicRadiusScatterDex: Double,
        baseSolidFraction: Double,
        annulusCount: Int,
        maximumEmbryoCount: Int,
        formationStepCount: Int,
        evolutionStepCount: Int,
        embryoSeedMassEarth: Double,
        solidAccretionEfficiency: Double,
        gasAccretionEfficiency: Double,
        migrationEfficiency: Double,
        formationMergerSpacing: Double,
        radialClearanceHillRadii: Double,
        finalPlanetSpacing: Double,
        finalGiantPlanetSpacing: Double,
        giantMassThresholdEarth: Double,
        atmosphereEscapeEfficiency: Double,
        maximumMoonCountPerPlanet: Int
    ) {
        self.modelVersion = modelVersion
        self.minimumStellarMassSolar = minimumStellarMassSolar
        self.maximumStellarMassSolar = maximumStellarMassSolar
        self.metallicityMeanDex = metallicityMeanDex
        self.metallicityStandardDeviationDex = metallicityStandardDeviationDex
        self.minimumMetallicityDex = minimumMetallicityDex
        self.maximumMetallicityDex = maximumMetallicityDex
        self.minimumSystemAgeGigayears = minimumSystemAgeGigayears
        self.maximumSystemAgeGigayears = maximumSystemAgeGigayears
        self.medianDiskMassRatio = medianDiskMassRatio
        self.diskMassScatterDex = diskMassScatterDex
        self.minimumDiskMassRatio = minimumDiskMassRatio
        self.maximumDiskMassRatio = maximumDiskMassRatio
        self.medianDiskLifetimeMegayears = medianDiskLifetimeMegayears
        self.diskLifetimeScatterDex = diskLifetimeScatterDex
        self.minimumDiskLifetimeMegayears = minimumDiskLifetimeMegayears
        self.maximumDiskLifetimeMegayears = maximumDiskLifetimeMegayears
        self.medianCharacteristicRadiusAU = medianCharacteristicRadiusAU
        self.characteristicRadiusScatterDex = characteristicRadiusScatterDex
        self.baseSolidFraction = baseSolidFraction
        self.annulusCount = annulusCount
        self.maximumEmbryoCount = maximumEmbryoCount
        self.formationStepCount = formationStepCount
        self.evolutionStepCount = evolutionStepCount
        self.embryoSeedMassEarth = embryoSeedMassEarth
        self.solidAccretionEfficiency = solidAccretionEfficiency
        self.gasAccretionEfficiency = gasAccretionEfficiency
        self.migrationEfficiency = migrationEfficiency
        self.formationMergerSpacing = formationMergerSpacing
        self.radialClearanceHillRadii = radialClearanceHillRadii
        self.finalPlanetSpacing = finalPlanetSpacing
        self.finalGiantPlanetSpacing = finalGiantPlanetSpacing
        self.giantMassThresholdEarth = giantMassThresholdEarth
        self.atmosphereEscapeEfficiency = atmosphereEscapeEfficiency
        self.maximumMoonCountPerPlanet = maximumMoonCountPerPlanet

        precondition(isValid, "Star system generation policy values are invalid.")
    }

    /// Returns the final mutual-Hill spacing required for one planetary pair.
    func requiredFinalSpacing(
        between firstMass: AstronomicalMass,
        and secondMass: AstronomicalMass
    ) -> Double {
        max(firstMass.earthMasses, secondMass.earthMasses) >= giantMassThresholdEarth
            ? finalGiantPlanetSpacing
            : finalPlanetSpacing
    }

    /// Whether one orbital pair has the calibrated eccentric radial clearance.
    func acceptsRadialClearance(
        _ clearance: OrbitalPairClearance,
        additiveSlack: Double = 0
    ) -> Bool {
        clearance.radialSeparation + additiveSlack
            >= radialClearanceHillRadii * clearance.mutualHillRadius
    }

    private static func isPositiveFinite(_ value: Double) -> Bool {
        value.isFinite && value > 0
    }

    private static func isNonnegativeFinite(_ value: Double) -> Bool {
        value.isFinite && value >= 0
    }

    private static func acceptsUnitFactor(_ value: Double) -> Bool {
        value.isFinite && value >= 0 && value <= 1
    }
}
