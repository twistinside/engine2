import Testing
@testable import Engine2

nonisolated struct GeneratedStarSystemLedgerTests {
    private let generator = StarSystemGenerator(policy: .coreAccretionLiteV1)
    private var ironOnlyComposition: CelestialMassComposition {
        CelestialMassComposition(
            iron: AstronomicalMass(earthMasses: 0.001),
            silicate: .zero,
            water: .zero,
            otherVolatiles: .zero,
            hydrogenHelium: .zero
        )
    }

    @Test func validationRejectsAnOpenSolidLedger() throws {
        let original = try generator.generate(seed: StarSystemSeed(rawValue: 102))
        let ledger = original.formationLedger
        let invalidLedger = replacing(
            ledger,
            unaccretedSolidMass: AstronomicalMass(
                earthMasses: ledger.unaccretedSolidMass.earthMasses + 1
            )
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
        let invalidLedger = replacing(
            ledger,
            unaccretedSolidComposition: invalidLeftover
        )
        let invalid = GeneratedStarSystemFixture(system: original).replacingLedger(invalidLedger)

        #expect(throws: StarSystemGenerationError.massConservationFailure(.solids)) {
            try invalid.validate()
        }
    }

    @Test func validationRejectsDynamicalLossCountCompositionMismatch() throws {
        let original = try generatedSystemWithEmptyDynamicalDestination()
        let ledger = original.formationLedger
        let invalidLosses = addingIronToEmptyDestination(
            in: ledger.dynamicalLosses,
            postDiskCollisionMergerCount: ledger.postDiskCollisionMergerCount
        )
        let invalid = GeneratedStarSystemFixture(system: original).replacingLedger(
            replacing(ledger, dynamicalLosses: invalidLosses)
        )

        #expect(throws: StarSystemGenerationError.invalidFormationLedger) {
            try invalid.validate()
        }
    }

    @Test func validationRejectsDynamicalLossMassCorruption() throws {
        let original = try generatedSystemWithRecordedDynamicalLoss()
        let ledger = original.formationLedger
        let invalidLosses = addingIronToRecordedDestination(
            in: ledger.dynamicalLosses,
            postDiskCollisionMergerCount: ledger.postDiskCollisionMergerCount
        )
        let invalid = GeneratedStarSystemFixture(system: original).replacingLedger(
            replacing(ledger, dynamicalLosses: invalidLosses)
        )

        #expect(throws: StarSystemGenerationError.massConservationFailure(.solids)) {
            try invalid.validate()
        }
    }

    @Test func validationThrowsInsteadOfTrappingWhenDynamicalDestinationAggregateOverflows() throws {
        let original = try generator.generate(seed: StarSystemSeed(rawValue: 1))
        let decoded = try GeneratedStarSystemFixture(system: original).decoded { object in
            var ledger = try #require(object["formationLedger"] as? [String: Any])
            var losses = try #require(ledger["dynamicalLosses"] as? [String: Any])
            var ejected = try #require(losses["ejectedComposition"] as? [String: Any])
            var ejectedIron = try #require(ejected["iron"] as? [String: Any])
            var debris = try #require(losses["collisionDebrisComposition"] as? [String: Any])
            var debrisIron = try #require(debris["iron"] as? [String: Any])
            ejectedIron["kilograms"] = 1e308
            debrisIron["kilograms"] = 1e308
            ejected["iron"] = ejectedIron
            debris["iron"] = debrisIron
            losses["ejectedComposition"] = ejected
            losses["collisionDebrisComposition"] = debris
            ledger["dynamicalLosses"] = losses
            object["formationLedger"] = ledger
        }
        let losses = decoded.formationLedger.dynamicalLosses
        let ejectedKilograms = rawKilogramTotal(losses.ejectedComposition)
        let debrisKilograms = rawKilogramTotal(losses.collisionDebrisComposition)

        #expect(ejectedKilograms.isFinite)
        #expect(debrisKilograms.isFinite)
        #expect(!(ejectedKilograms + debrisKilograms).isFinite)
        #expect(throws: StarSystemGenerationError.invalidFormationLedger) {
            try decoded.validate()
        }
    }

    @Test func validationRejectsHydrogenHeliumOnlyRecordedBodyWithClosedLedger() throws {
        let original = try generator.generate(seed: StarSystemSeed(rawValue: 1))
        let ledger = original.formationLedger
        let losses = ledger.dynamicalLosses
        #expect(losses.ejectedBodyCount > 0)
        let ejected = losses.ejectedComposition
        let returnedSolid = ejected.replacingHydrogenHelium(with: .zero)
        let transferredHydrogenHeliumEarth = min(
            0.001,
            ledger.dispersedGasMass.earthMasses / 2
        )
        let hydrogenHeliumOnly = CelestialMassComposition(
            iron: .zero,
            silicate: .zero,
            water: .zero,
            otherVolatiles: .zero,
            hydrogenHelium: AstronomicalMass(
                earthMasses: ejected.hydrogenHelium.earthMasses
                    + transferredHydrogenHeliumEarth
            )
        )
        let invalidLosses = replacing(
            losses,
            ejectedComposition: hydrogenHeliumOnly
        )
        let invalidUnaccreted = ledger.unaccretedSolidComposition.adding(returnedSolid)
        let invalidLedger = replacing(
            ledger,
            unaccretedSolidMass: invalidUnaccreted.solidMass,
            unaccretedSolidComposition: invalidUnaccreted,
            dispersedGasMass: AstronomicalMass(
                earthMasses: ledger.dispersedGasMass.earthMasses
                    - transferredHydrogenHeliumEarth
            ),
            dynamicalLosses: invalidLosses
        )
        let invalid = GeneratedStarSystemFixture(system: original).replacingLedger(invalidLedger)
        let originalChangedSolidEarth = ledger.unaccretedSolidMass.earthMasses
            + ejected.solidMass.earthMasses
        let invalidChangedSolidEarth = invalidLedger.unaccretedSolidMass.earthMasses
            + hydrogenHeliumOnly.solidMass.earthMasses
        let originalChangedGasEarth = ledger.dispersedGasMass.earthMasses
            + ejected.hydrogenHelium.earthMasses
        let invalidChangedGasEarth = invalidLedger.dispersedGasMass.earthMasses
            + hydrogenHeliumOnly.hydrogenHelium.earthMasses

        #expect(transferredHydrogenHeliumEarth > 0)
        #expect(hydrogenHeliumOnly.solidMass == .zero)
        #expect(hydrogenHeliumOnly.hydrogenHelium > .zero)
        #expect(abs(originalChangedSolidEarth - invalidChangedSolidEarth) < 1e-9)
        #expect(abs(originalChangedGasEarth - invalidChangedGasEarth) < 1e-9)
        #expect(throws: StarSystemGenerationError.invalidFormationLedger) {
            try invalid.validate()
        }
    }

    @Test func validationRejectsResidualBodyCountCompositionMismatch() throws {
        let original = try generator.generate(seed: StarSystemSeed(rawValue: 106))
        let ledger = original.formationLedger
        let invalidResidualComposition = ledger.residualBodyComposition.adding(ironOnlyComposition)
        let invalid = GeneratedStarSystemFixture(system: original).replacingLedger(
            replacing(
                ledger,
                residualBodyComposition: invalidResidualComposition,
                residualBodyCount: 0,
                residualProgenitorCount: 0
            )
        )

        #expect(throws: StarSystemGenerationError.invalidFormationLedger) {
            try invalid.validate()
        }
    }

    @Test func validationRejectsAnOverweightResidualPopulationWithClosedSolidLedger() throws {
        let original = try generatedSystemWithResidualBodies()
        let ledger = original.formationLedger
        let maximumResidualSolidMassEarth = original.policy.minimumResolvedPlanetSolidMassEarth
            * Double(ledger.residualBodyCount)
            * (1 + 1e-9)
        let transferredSolidMassEarth = maximumResidualSolidMassEarth
            - ledger.residualBodyComposition.solidMass.earthMasses
            + 0.001
        let unaccreted = ledger.unaccretedSolidComposition
        let transferredFraction = transferredSolidMassEarth / unaccreted.solidMass.earthMasses
        let transferred = unaccreted.scaled(by: transferredFraction)
        let remainingUnaccreted = unaccreted.scaled(by: 1 - transferredFraction)
        let invalidResidual = ledger.residualBodyComposition.adding(transferred)
        let invalidLedger = replacing(
            ledger,
            unaccretedSolidMass: remainingUnaccreted.solidMass,
            unaccretedSolidComposition: remainingUnaccreted,
            residualBodyComposition: invalidResidual
        )
        let invalid = GeneratedStarSystemFixture(system: original).replacingLedger(invalidLedger)
        let originalAccountedSolidMassEarth = ledger.unaccretedSolidMass.earthMasses
            + ledger.residualBodyComposition.solidMass.earthMasses
        let invalidAccountedSolidMassEarth = invalidLedger.unaccretedSolidMass.earthMasses
            + invalidLedger.residualBodyComposition.solidMass.earthMasses

        #expect(transferredFraction > 0 && transferredFraction < 1)
        #expect(abs(originalAccountedSolidMassEarth - invalidAccountedSolidMassEarth) < 1e-9)
        #expect(throws: StarSystemGenerationError.invalidFormationLedger) {
            try invalid.validate()
        }
    }

    private func generatedSystemWithEmptyDynamicalDestination() throws -> GeneratedStarSystem {
        var match: GeneratedStarSystem?
        for rawSeed in 0..<32 {
            let system = try generator.generate(seed: StarSystemSeed(rawValue: UInt64(rawSeed)))
            let ledger = system.formationLedger
            let losses = ledger.dynamicalLosses
            if losses.ejectedBodyCount == 0
                || losses.starAccretedBodyCount == 0
                || ledger.postDiskCollisionMergerCount == 0 {
                match = system
                break
            }
        }
        return try #require(match, "The bounded seed range must include an unused dynamical destination.")
    }

    private func generatedSystemWithRecordedDynamicalLoss() throws -> GeneratedStarSystem {
        var match: GeneratedStarSystem?
        for rawSeed in 0..<32 {
            let system = try generator.generate(seed: StarSystemSeed(rawValue: UInt64(rawSeed)))
            let ledger = system.formationLedger
            let losses = ledger.dynamicalLosses
            if losses.ejectedBodyCount > 0
                || losses.starAccretedBodyCount > 0
                || ledger.postDiskCollisionMergerCount > 0 {
                match = system
                break
            }
        }
        return try #require(match, "The bounded seed range must include a recorded dynamical loss.")
    }

    private func generatedSystemWithResidualBodies() throws -> GeneratedStarSystem {
        var match: GeneratedStarSystem?
        for rawSeed in 0..<32 {
            let system = try generator.generate(seed: StarSystemSeed(rawValue: UInt64(rawSeed)))
            if system.formationLedger.residualBodyCount > 0 {
                match = system
                break
            }
        }
        return try #require(match, "The bounded seed range must include residual formation bodies.")
    }

    private func addingIronToEmptyDestination(
        in losses: StarSystemDynamicalLossLedger,
        postDiskCollisionMergerCount: Int
    ) -> StarSystemDynamicalLossLedger {
        if losses.ejectedBodyCount == 0 {
            return replacing(
                losses,
                ejectedComposition: losses.ejectedComposition.adding(ironOnlyComposition)
            )
        }
        if losses.starAccretedBodyCount == 0 {
            return replacing(
                losses,
                starAccretedComposition: losses.starAccretedComposition.adding(ironOnlyComposition)
            )
        }
        precondition(postDiskCollisionMergerCount == 0)
        return replacing(
            losses,
            collisionDebrisComposition: losses.collisionDebrisComposition.adding(ironOnlyComposition)
        )
    }

    private func addingIronToRecordedDestination(
        in losses: StarSystemDynamicalLossLedger,
        postDiskCollisionMergerCount: Int
    ) -> StarSystemDynamicalLossLedger {
        if losses.ejectedBodyCount > 0 {
            return replacing(
                losses,
                ejectedComposition: losses.ejectedComposition.adding(ironOnlyComposition)
            )
        }
        if losses.starAccretedBodyCount > 0 {
            return replacing(
                losses,
                starAccretedComposition: losses.starAccretedComposition.adding(ironOnlyComposition)
            )
        }
        precondition(postDiskCollisionMergerCount > 0)
        return replacing(
            losses,
            collisionDebrisComposition: losses.collisionDebrisComposition.adding(ironOnlyComposition)
        )
    }

    private func replacing(
        _ losses: StarSystemDynamicalLossLedger,
        ejectedComposition: CelestialMassComposition? = nil,
        starAccretedComposition: CelestialMassComposition? = nil,
        collisionDebrisComposition: CelestialMassComposition? = nil
    ) -> StarSystemDynamicalLossLedger {
        StarSystemDynamicalLossLedger(
            ejectedComposition: ejectedComposition ?? losses.ejectedComposition,
            starAccretedComposition: starAccretedComposition ?? losses.starAccretedComposition,
            collisionDebrisComposition: collisionDebrisComposition ?? losses.collisionDebrisComposition,
            scatteringCount: losses.scatteringCount,
            ejectedBodyCount: losses.ejectedBodyCount,
            ejectedProgenitorCount: losses.ejectedProgenitorCount,
            starAccretedBodyCount: losses.starAccretedBodyCount,
            starAccretedProgenitorCount: losses.starAccretedProgenitorCount
        )
    }

    private func replacing(
        _ ledger: StarSystemFormationLedger,
        unaccretedSolidMass: AstronomicalMass? = nil,
        unaccretedSolidComposition: CelestialMassComposition? = nil,
        dispersedGasMass: AstronomicalMass? = nil,
        dynamicalLosses: StarSystemDynamicalLossLedger? = nil,
        residualBodyComposition: CelestialMassComposition? = nil,
        residualBodyCount: Int? = nil,
        residualProgenitorCount: Int? = nil
    ) -> StarSystemFormationLedger {
        StarSystemFormationLedger(
            initialSolidMass: ledger.initialSolidMass,
            retainedSolidMass: ledger.retainedSolidMass,
            unaccretedSolidMass: unaccretedSolidMass ?? ledger.unaccretedSolidMass,
            unaccretedSolidComposition: unaccretedSolidComposition ?? ledger.unaccretedSolidComposition,
            initialGasMass: ledger.initialGasMass,
            retainedHydrogenHeliumMass: ledger.retainedHydrogenHeliumMass,
            escapedHydrogenHeliumMass: ledger.escapedHydrogenHeliumMass,
            dispersedGasMass: dispersedGasMass ?? ledger.dispersedGasMass,
            dynamicalLosses: dynamicalLosses ?? ledger.dynamicalLosses,
            residualBodyComposition: residualBodyComposition ?? ledger.residualBodyComposition,
            residualBodyCount: residualBodyCount ?? ledger.residualBodyCount,
            residualProgenitorCount: residualProgenitorCount ?? ledger.residualProgenitorCount,
            seededEmbryoCount: ledger.seededEmbryoCount,
            formationMergerCount: ledger.formationMergerCount,
            postDiskCollisionMergerCount: ledger.postDiskCollisionMergerCount
        )
    }

    private func rawKilogramTotal(_ composition: CelestialMassComposition) -> Double {
        composition.iron.kilograms
            + composition.silicate.kilograms
            + composition.water.kilograms
            + composition.otherVolatiles.kilograms
            + composition.hydrogenHelium.kilograms
    }
}
