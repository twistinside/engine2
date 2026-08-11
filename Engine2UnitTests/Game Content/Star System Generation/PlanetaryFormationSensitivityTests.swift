import Testing
@testable import Engine2

nonisolated struct PlanetaryFormationSensitivityTests {
    private let policy = StarSystemGenerationPolicy.coreAccretionLiteV1

    @Test func longerLivedIdenticalDiskIncreasesAccretionAndInwardMigration() throws {
        let seed = StarSystemSeed(rawValue: 71)
        let star = MainSequenceStarGenerator(policy: policy).generate(seed: seed)
        let disk = ProtoplanetaryDiskGenerator(policy: policy).generate(
            around: star,
            seed: seed
        )
        let shortResult = try PlanetaryFormationSimulator(policy: policy).formPlanets(
            in: replacingLifetime(of: disk, withMegayears: 1),
            around: star,
            seed: seed
        )
        let longResult = try PlanetaryFormationSimulator(policy: policy).formPlanets(
            in: replacingLifetime(of: disk, withMegayears: 10),
            around: star,
            seed: seed
        )
        let shortRetainedSolid = shortResult.embryos.reduce(0) {
            $0 + $1.composition.solidMass.earthMasses
        }
        let longRetainedSolid = longResult.embryos.reduce(0) {
            $0 + $1.composition.solidMass.earthMasses
        }
        let shortMeanAxis = shortResult.embryos.reduce(0) { $0 + $1.semiMajorAxisAU }
            / Double(shortResult.embryos.count)
        let longMeanAxis = longResult.embryos.reduce(0) { $0 + $1.semiMajorAxisAU }
            / Double(longResult.embryos.count)

        #expect(longRetainedSolid > shortRetainedSolid)
        #expect(longMeanAxis < shortMeanAxis)
    }

    private func replacingLifetime(
        of disk: FormationDisk,
        withMegayears lifetimeMegayears: Double
    ) -> FormationDisk {
        let summary = disk.summary
        return FormationDisk(
            summary: GeneratedProtoplanetaryDisk(
                initialGasMass: summary.initialGasMass,
                initialSolidMass: summary.initialSolidMass,
                initialSolidComposition: summary.initialSolidComposition,
                lifetime: AstronomicalDuration(megayears: lifetimeMegayears),
                characteristicRadius: summary.characteristicRadius,
                surfaceDensityExponent: summary.surfaceDensityExponent,
                innerEdge: summary.innerEdge,
                outerEdge: summary.outerEdge,
                waterSnowLine: summary.waterSnowLine,
                annulusCount: summary.annulusCount
            ),
            annuli: disk.annuli,
            dispersedGasMassEarth: disk.dispersedGasMassEarth
        )
    }
}
