import Testing
@testable import Engine2

nonisolated struct GeneratedStarSystemLedgerTests {
    private let generator = StarSystemGenerator(policy: .coreAccretionLiteV1)

    @Test func validationRejectsAnOpenSolidLedger() throws {
        let original = try generator.generate(seed: StarSystemSeed(rawValue: 102))
        let ledger = original.formationLedger
        let invalidLedger = StarSystemFormationLedger(
            initialSolidMass: ledger.initialSolidMass,
            retainedSolidMass: ledger.retainedSolidMass,
            unaccretedSolidMass: AstronomicalMass(
                earthMasses: ledger.unaccretedSolidMass.earthMasses + 1
            ),
            unaccretedSolidComposition: ledger.unaccretedSolidComposition,
            initialGasMass: ledger.initialGasMass,
            retainedHydrogenHeliumMass: ledger.retainedHydrogenHeliumMass,
            escapedHydrogenHeliumMass: ledger.escapedHydrogenHeliumMass,
            dispersedGasMass: ledger.dispersedGasMass,
            seededEmbryoCount: ledger.seededEmbryoCount,
            formationMergerCount: ledger.formationMergerCount,
            stabilityMergerCount: ledger.stabilityMergerCount
        )
        let invalid = GeneratedStarSystemFixture(system: original).replacingLedger(invalidLedger)

        #expect(throws: StarSystemGenerationError.massConservationFailure(.solids)) {
            try invalid.validate()
        }
    }

    @Test func validationRejectsNegativeDecodedLedgerMass() throws {
        let original = try generator.generate(seed: StarSystemSeed(rawValue: 104))
        let decoded = try GeneratedStarSystemFixture(system: original).decoded { object in
            var ledger = try #require(object["formationLedger"] as? [String: Any])
            var dispersed = try #require(ledger["dispersedGasMass"] as? [String: Any])
            dispersed["kilograms"] = -1.0
            ledger["dispersedGasMass"] = dispersed
            object["formationLedger"] = ledger
        }

        #expect(throws: StarSystemGenerationError.invalidFormationLedger) {
            try decoded.validate()
        }
    }

    @Test func validationRejectsComponentLedgerCorruption() throws {
        let original = try generator.generate(seed: StarSystemSeed(rawValue: 105))
        let ledger = original.formationLedger
        let leftover = ledger.unaccretedSolidComposition
        let transferredMassEarth = min(0.001, leftover.silicate.earthMasses / 2)
        #expect(transferredMassEarth > 0)
        let invalidLeftover = CelestialMassComposition(
            iron: AstronomicalMass(
                earthMasses: leftover.iron.earthMasses + transferredMassEarth
            ),
            silicate: AstronomicalMass(
                earthMasses: leftover.silicate.earthMasses - transferredMassEarth
            ),
            water: leftover.water,
            otherVolatiles: leftover.otherVolatiles,
            hydrogenHelium: leftover.hydrogenHelium
        )
        let invalidLedger = StarSystemFormationLedger(
            initialSolidMass: ledger.initialSolidMass,
            retainedSolidMass: ledger.retainedSolidMass,
            unaccretedSolidMass: ledger.unaccretedSolidMass,
            unaccretedSolidComposition: invalidLeftover,
            initialGasMass: ledger.initialGasMass,
            retainedHydrogenHeliumMass: ledger.retainedHydrogenHeliumMass,
            escapedHydrogenHeliumMass: ledger.escapedHydrogenHeliumMass,
            dispersedGasMass: ledger.dispersedGasMass,
            seededEmbryoCount: ledger.seededEmbryoCount,
            formationMergerCount: ledger.formationMergerCount,
            stabilityMergerCount: ledger.stabilityMergerCount
        )
        let invalid = GeneratedStarSystemFixture(system: original).replacingLedger(invalidLedger)

        #expect(throws: StarSystemGenerationError.massConservationFailure(.solids)) {
            try invalid.validate()
        }
    }
}
