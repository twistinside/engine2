import Foundation

/// Evolves fully funded embryos through bounded accretion, gas capture, migration, and collisions.
///
/// Every epoch calculates material claims from one pre-application snapshot and
/// proportionally scales contested annuli. Gas growth and migration use local
/// supply and gap state. Collision debris returns to explicit disk destinations.
nonisolated struct PlanetaryFormationSimulator: Sendable {
    private static let diskTurbulentViscosityAlpha = 0.002
    private static let gasCaptureHillRadii = 0.75
    private static let maximumEmbryoFormationRadiusAU = 40.0
    private static let minimumGasCapturingCoreMassEarth = 0.3
    private static let minimumGapFlowFactor = 0.02
    private static let runawayEnvelopeToCoreMassRatio = 0.45

    let policy: StarSystemGenerationPolicy

    func formPlanets(
        in initialDisk: FormationDisk,
        around star: GeneratedStar,
        seed: StarSystemSeed
    ) throws(StarSystemGenerationError) -> PlanetaryFormationResult {
        var disk = initialDisk
        var placementRandom = StarSystemRandomStream(
            seed: seed,
            modelVersion: policy.modelVersion,
            domain: .embryos
        )
        var formationRandom = StarSystemRandomStream(
            seed: seed,
            modelVersion: policy.modelVersion,
            domain: .formation
        )
        var embryos = seedEmbryos(
            in: &disk,
            around: star,
            random: &placementRandom
        )
        guard !embryos.isEmpty else {
            throw .noFundedEmbryos
        }
        let seededEmbryoCount = embryos.count
        var formationMergerCount = 0
        let diskLifetimeMegayears = disk.summary.lifetime.megayears
        let epochDurationMegayears = diskLifetimeMegayears / Double(policy.formationStepCount)

        for step in 0..<policy.formationStepCount {
            embryos.sort { $0.id < $1.id }
            applySimultaneousSolidAccretion(
                to: &embryos,
                from: &disk,
                around: star,
                epochDurationMegayears: epochDurationMegayears
            )
            applySimultaneousGasCapture(
                to: &embryos,
                from: &disk,
                around: star,
                elapsedMegayears: Double(step + 1) * epochDurationMegayears,
                epochDurationMegayears: epochDurationMegayears
            )
            applyDiskDrivenMigration(
                to: &embryos,
                through: disk,
                around: star,
                epochDurationMegayears: epochDurationMegayears
            )
            disperseGasEpoch(
                in: &disk,
                epochDurationMegayears: epochDurationMegayears,
                diskLifetimeMegayears: diskLifetimeMegayears
            )

            if (step + 1).isMultiple(of: 8) {
                formationMergerCount += resolveCloseEmbryosDuringGasDisk(
                    &embryos,
                    disk: &disk,
                    around: star,
                    random: &formationRandom
                )
            }
        }
        formationMergerCount += resolveCloseEmbryosDuringGasDisk(
            &embryos,
            disk: &disk,
            around: star,
            random: &formationRandom
        )
        disperseRemainingGas(in: &disk)
        embryos.sort {
            ($0.semiMajorAxisAU, $0.id.rawValue) < ($1.semiMajorAxisAU, $1.id.rawValue)
        }

        return PlanetaryFormationResult(
            disk: disk,
            embryos: embryos,
            seededEmbryoCount: seededEmbryoCount,
            formationMergerCount: formationMergerCount
        )
    }

    private func seedEmbryos(
        in disk: inout FormationDisk,
        around star: GeneratedStar,
        random: inout StarSystemRandomStream
    ) -> [FormationEmbryo] {
        let innerEdgeAU = disk.summary.innerEdge.astronomicalUnits
        let outerEdgeAU = min(
            Self.maximumEmbryoFormationRadiusAU,
            disk.summary.outerEdge.astronomicalUnits
        )
        var radiusAU = innerEdgeAU * random.uniform(in: 1.25...1.45)
        var embryos: [FormationEmbryo] = []

        while radiusAU < outerEdgeAU && embryos.count < policy.maximumEmbryoCount {
            let nearestAnnulus = nearestAnnulusIndex(to: radiusAU, in: disk.annuli)
            let seedComposition = withdrawSeedComposition(
                targetMassEarth: policy.embryoSeedMassEarth,
                nearestAnnulus: nearestAnnulus,
                annuli: &disk.annuli
            )
            if seedComposition.solidMass.earthMasses > 0 {
                embryos.append(
                    FormationEmbryo(
                        id: .planet(formationIndex: embryos.count),
                        semiMajorAxisAU: radiusAU,
                        eccentricity: 0,
                        inclinationDegrees: 0,
                        composition: seedComposition,
                        progenitorCount: 1
                    )
                )
            }
            let geometricSpacingAU = radiusAU * (random.uniform(in: 1.16...1.28) - 1)
            let mutualHillRadiusAU = radiusAU * pow(
                2 * policy.embryoSeedMassEarth / (3 * star.mass.earthMasses),
                1.0 / 3.0
            )
            let hillSpacingAU = max(8, 2 * policy.formationMergerSpacing) * mutualHillRadiusAU
            radiusAU += max(geometricSpacingAU, hillSpacingAU)
        }
        return embryos
    }

    private func withdrawSeedComposition(
        targetMassEarth: Double,
        nearestAnnulus: Int,
        annuli: inout [FormationAnnulus]
    ) -> CelestialMassComposition {
        let lower = max(0, nearestAnnulus - 2)
        let upper = min(annuli.count - 1, nearestAnnulus + 2)
        let available = annuli[lower...upper].reduce(0) { $0 + $1.remainingSolidMassEarth }
        guard available >= targetMassEarth else {
            return .zero
        }
        let withdrawnFraction = targetMassEarth / available
        var withdrawn = CelestialMassComposition.zero
        for index in lower...upper {
            let source = annuli[index].solidComposition
            withdrawn = withdrawn.adding(source.scaled(by: withdrawnFraction))
            annuli[index].solidComposition = source.scaled(by: 1 - withdrawnFraction)
        }
        return withdrawn
    }

    private func applySimultaneousSolidAccretion(
        to embryos: inout [FormationEmbryo],
        from disk: inout FormationDisk,
        around star: GeneratedStar,
        epochDurationMegayears: Double
    ) {
        let annulusSnapshot = disk.annuli
        let embryoSnapshot = embryos
        let claims = makeSolidClaims(
            embryos: embryoSnapshot,
            annuli: annulusSnapshot,
            around: star,
            epochDurationMegayears: epochDurationMegayears
        )
        let gains = allocateSolidClaims(
            claims,
            from: annulusSnapshot,
            into: &disk
        )
        applySolidGains(gains, to: &embryos, from: embryoSnapshot)
    }

    private func makeSolidClaims(
        embryos: [FormationEmbryo],
        annuli: [FormationAnnulus],
        around star: GeneratedStar,
        epochDurationMegayears: Double
    ) -> [[Double]] {
        var claims = Array(
            repeating: Array(repeating: 0.0, count: annuli.count),
            count: embryos.count
        )

        for embryoIndex in embryos.indices {
            let embryo = embryos[embryoIndex]
            let halfWidth = feedingZoneHalfWidthAU(for: embryo, around: star)
            let accretionRatePerMegayear = 30
                * policy.solidAccretionEfficiency
                * pow(max(embryo.composition.solidMass.earthMasses, 1e-6), 2.0 / 3.0)
                * pow(max(embryo.semiMajorAxisAU, 0.03), -0.5)
            let baseClaim = min(
                0.25,
                1 - exp(-accretionRatePerMegayear * epochDurationMegayears)
            )
            for annulusIndex in annuli.indices {
                let annulus = annuli[annulusIndex]
                let distance = abs(annulus.centerRadiusAU - embryo.semiMajorAxisAU)
                guard distance <= halfWidth else {
                    continue
                }
                let taper = max(0, 1 - distance / max(halfWidth, annulus.widthAU))
                claims[embryoIndex][annulusIndex] = baseClaim * (0.25 + 0.75 * taper)
            }
        }
        return claims
    }

    private func allocateSolidClaims(
        _ claims: [[Double]],
        from annuli: [FormationAnnulus],
        into disk: inout FormationDisk
    ) -> [CelestialMassComposition] {
        var gains = Array(repeating: CelestialMassComposition.zero, count: claims.count)
        for annulusIndex in annuli.indices {
            let totalClaim = claims.reduce(0) { $0 + $1[annulusIndex] }
            guard totalClaim > 0 else {
                continue
            }
            let allocationScale = min(1, 1 / totalClaim)
            let source = annuli[annulusIndex].solidComposition
            let withdrawnFraction = min(1, totalClaim)
            for embryoIndex in claims.indices {
                let allocatedFraction = claims[embryoIndex][annulusIndex] * allocationScale
                gains[embryoIndex] = gains[embryoIndex].adding(source.scaled(by: allocatedFraction))
            }
            disk.annuli[annulusIndex].solidComposition = source.scaled(by: 1 - withdrawnFraction)
        }
        return gains
    }

    private func applySolidGains(
        _ gains: [CelestialMassComposition],
        to embryos: inout [FormationEmbryo],
        from embryoSnapshot: [FormationEmbryo]
    ) {
        for embryoIndex in embryos.indices {
            embryos[embryoIndex].composition = embryoSnapshot[embryoIndex].composition.adding(gains[embryoIndex])
        }
    }

    private func applySimultaneousGasCapture(
        to embryos: inout [FormationEmbryo],
        from disk: inout FormationDisk,
        around star: GeneratedStar,
        elapsedMegayears: Double,
        epochDurationMegayears: Double
    ) {
        let annulusSnapshot = disk.annuli
        let embryoSnapshot = embryos
        let requestedMasses = makeGasCaptureRequests(
            embryos: embryoSnapshot,
            annuli: annulusSnapshot,
            around: star,
            elapsedMegayears: elapsedMegayears,
            epochDurationMegayears: epochDurationMegayears
        )
        let gasGains = allocateGasCaptureRequests(
            requestedMasses,
            from: annulusSnapshot,
            into: &disk
        )
        applyGasGains(gasGains, to: &embryos, from: embryoSnapshot)
    }

    private func makeGasCaptureRequests(
        embryos: [FormationEmbryo],
        annuli: [FormationAnnulus],
        around star: GeneratedStar,
        elapsedMegayears: Double,
        epochDurationMegayears: Double
    ) -> [[Double]] {
        var requestedMasses = Array(
            repeating: Array(repeating: 0.0, count: annuli.count),
            count: embryos.count
        )

        for embryoIndex in embryos.indices {
            let embryo = embryos[embryoIndex]
            let coolingDemandEarth = coolingLimitedGasDemandEarth(
                for: embryo,
                elapsedMegayears: elapsedMegayears,
                epochDurationMegayears: epochDurationMegayears
            )
            guard coolingDemandEarth > 0 else {
                continue
            }
            let halfWidth = gasCaptureHalfWidthAU(for: embryo, around: star)
            let localIndices = annuli.indices.filter { index in
                annuli[index].innerRadiusAU <= embryo.semiMajorAxisAU + halfWidth
                    && annuli[index].outerRadiusAU >= embryo.semiMajorAxisAU - halfWidth
            }
            let localGas = localIndices.reduce(0) { $0 + annuli[$1].remainingGasMassEarth }
            guard localGas > 0 else {
                continue
            }
            let gapDepth = diskGapDepth(for: embryo, around: star)
            let gapFlowFactor = max(Self.minimumGapFlowFactor, sqrt(gapDepth))
            let hydrodynamicResponsePerMegayear = 3
                * policy.gasAccretionEfficiency
                * pow(max(embryo.composition.totalMass.earthMasses, 0.1) / 10, 2.0 / 3.0)
            let hydrodynamicSupplyEarth = localGas
                * (1 - exp(-hydrodynamicResponsePerMegayear * epochDurationMegayears))
                * gapFlowFactor
            let viscousTimescale = viscousTimescaleMegayears(
                at: embryo.semiMajorAxisAU,
                around: star
            )
            let viscousSupplyEarth = localGas
                * (1 - exp(-epochDurationMegayears / viscousTimescale))
                * gapFlowFactor
            let requestedEnvelope = min(
                coolingDemandEarth,
                min(hydrodynamicSupplyEarth, viscousSupplyEarth)
            )
            for annulusIndex in localIndices {
                let share = annuli[annulusIndex].remainingGasMassEarth / localGas
                requestedMasses[embryoIndex][annulusIndex] = requestedEnvelope * share
            }
        }
        return requestedMasses
    }

    private func coolingLimitedGasDemandEarth(
        for embryo: FormationEmbryo,
        elapsedMegayears: Double,
        epochDurationMegayears: Double
    ) -> Double {
        let coreMassEarth = embryo.composition.solidMass.earthMasses
        guard coreMassEarth >= Self.minimumGasCapturingCoreMassEarth else {
            return 0
        }
        let currentEnvelopeEarth = embryo.composition.hydrogenHelium.earthMasses
        let supportedEnvelopeRatio = min(
            1,
            0.0025
                * pow(coreMassEarth, 1.7)
                * sqrt(max(elapsedMegayears, 1e-6))
        )
        let supportedEnvelopeEarth = coreMassEarth * supportedEnvelopeRatio
        let kelvinHelmholtzTimescaleMegayears = max(
            0.01,
            4 * pow(coreMassEarth / 5, -3)
        )
        let coolingResponse = 1 - exp(
            -policy.gasAccretionEfficiency
                * epochDurationMegayears
                / kelvinHelmholtzTimescaleMegayears
        )
        let attachedDemandEarth = max(
            0,
            supportedEnvelopeEarth - currentEnvelopeEarth
        ) * coolingResponse
        guard currentEnvelopeEarth >= Self.runawayEnvelopeToCoreMassRatio * coreMassEarth else {
            return attachedDemandEarth
        }
        let runawayExponent = min(
            3,
            policy.gasAccretionEfficiency
                * epochDurationMegayears
                / kelvinHelmholtzTimescaleMegayears
        )
        let runawayDemandEarth = max(currentEnvelopeEarth, 0.01 * coreMassEarth)
            * expm1(runawayExponent)
        return max(attachedDemandEarth, runawayDemandEarth)
    }

    private func allocateGasCaptureRequests(
        _ requestedMasses: [[Double]],
        from annuli: [FormationAnnulus],
        into disk: inout FormationDisk
    ) -> [Double] {
        var gasGains = Array(repeating: 0.0, count: requestedMasses.count)
        for annulusIndex in annuli.indices {
            let totalRequest = requestedMasses.reduce(0) { $0 + $1[annulusIndex] }
            guard totalRequest > 0 else {
                continue
            }
            let available = annuli[annulusIndex].remainingGasMassEarth
            let allocationScale = min(1, available / totalRequest)
            var allocated = 0.0
            for embryoIndex in requestedMasses.indices {
                let gain = requestedMasses[embryoIndex][annulusIndex] * allocationScale
                gasGains[embryoIndex] += gain
                allocated += gain
            }
            disk.annuli[annulusIndex].remainingGasMassEarth = max(0, available - allocated)
        }
        return gasGains
    }

    private func applyGasGains(
        _ gasGains: [Double],
        to embryos: inout [FormationEmbryo],
        from embryoSnapshot: [FormationEmbryo]
    ) {
        for embryoIndex in embryos.indices {
            let composition = embryoSnapshot[embryoIndex].composition
            let retainedGas = composition.hydrogenHelium.earthMasses + gasGains[embryoIndex]
            embryos[embryoIndex].composition = composition.replacingHydrogenHelium(
                with: AstronomicalMass(earthMasses: retainedGas)
            )
        }
    }

    private func applyDiskDrivenMigration(
        to embryos: inout [FormationEmbryo],
        through disk: FormationDisk,
        around star: GeneratedStar,
        epochDurationMegayears: Double
    ) {
        for index in embryos.indices {
            let embryo = embryos[index]
            let nearestAnnulus = nearestAnnulusIndex(
                to: embryo.semiMajorAxisAU,
                in: disk.annuli
            )
            let annulus = disk.annuli[nearestAnnulus]
            let localGasAvailability = annulus.initialGasMassEarth > 0
                ? annulus.remainingGasMassEarth / annulus.initialGasMassEarth
                : 0
            let massEarth = embryo.composition.totalMass.earthMasses
            let typeIMigrationRatePerMegayear = 0.384
                * policy.migrationEfficiency
                * massEarth / (1 + massEarth / 30)
                * localGasAvailability
            let gapOpeningParameter = diskGapOpeningParameter(
                for: embryo,
                around: star
            )
            let migrationRatePerMegayear: Double
            let attractorAU: Double
            if gapOpeningParameter <= 1 {
                let viscousTimescale = viscousTimescaleMegayears(
                    at: embryo.semiMajorAxisAU,
                    around: star
                )
                migrationRatePerMegayear = min(
                    typeIMigrationRatePerMegayear * max(0.03, diskGapDepth(for: embryo, around: star)),
                    1 / viscousTimescale
                )
                attractorAU = min(
                    embryo.semiMajorAxisAU,
                    innerMigrationTrapAU(in: disk)
                )
            } else {
                migrationRatePerMegayear = typeIMigrationRatePerMegayear
                attractorAU = typeIMigrationAttractorAU(for: embryo, in: disk)
            }
            let fractionalStep = min(
                0.03,
                1 - exp(-migrationRatePerMegayear * epochDurationMegayears)
            )
            let radialStepAU = embryo.semiMajorAxisAU * fractionalStep
            if attractorAU < embryo.semiMajorAxisAU {
                embryos[index].semiMajorAxisAU = max(
                    attractorAU,
                    embryo.semiMajorAxisAU - radialStepAU
                )
            } else {
                embryos[index].semiMajorAxisAU = min(
                    attractorAU,
                    embryo.semiMajorAxisAU + radialStepAU
                )
            }
        }
    }

    private func viscousTimescaleMegayears(
        at semiMajorAxisAU: Double,
        around star: GeneratedStar
    ) -> Double {
        max(
            0.05,
            0.35
                * pow(max(semiMajorAxisAU, 0.03) / 5, 0.75)
                / sqrt(star.mass.solarMasses)
        )
    }

    private func typeIMigrationAttractorAU(
        for embryo: FormationEmbryo,
        in disk: FormationDisk
    ) -> Double {
        let snowLineAU = disk.summary.waterSnowLine.astronomicalUnits
        let innerTrapAU = innerMigrationTrapAU(in: disk)
        let distanceToInnerTrap = abs(log(embryo.semiMajorAxisAU / innerTrapAU))
        let distanceToSnowLine = abs(log(embryo.semiMajorAxisAU / snowLineAU))
        let baseAttractorAU = distanceToInnerTrap < distanceToSnowLine
            ? innerTrapAU
            : snowLineAU
        return baseAttractorAU
    }

    private func innerMigrationTrapAU(in disk: FormationDisk) -> Double {
        max(
            1.8 * disk.summary.innerEdge.astronomicalUnits,
            0.18 * disk.summary.waterSnowLine.astronomicalUnits
        )
    }

    private func disperseGasEpoch(
        in disk: inout FormationDisk,
        epochDurationMegayears: Double,
        diskLifetimeMegayears: Double
    ) {
        let survivalFactor = exp(-3 * epochDurationMegayears / diskLifetimeMegayears)
        for index in disk.annuli.indices {
            let before = disk.annuli[index].remainingGasMassEarth
            let after = before * survivalFactor
            disk.annuli[index].remainingGasMassEarth = after
            disk.dispersedGasMassEarth += before - after
        }
    }

    private func disperseRemainingGas(in disk: inout FormationDisk) {
        for index in disk.annuli.indices {
            disk.dispersedGasMassEarth += disk.annuli[index].remainingGasMassEarth
            disk.annuli[index].remainingGasMassEarth = 0
        }
    }

    private func resolveCloseEmbryosDuringGasDisk(
        _ embryos: inout [FormationEmbryo],
        disk: inout FormationDisk,
        around star: GeneratedStar,
        random: inout StarSystemRandomStream
    ) -> Int {
        var mergerCount = 0
        var foundMerger = true
        while foundMerger && embryos.count > 1 {
            foundMerger = false
            embryos.sort {
                ($0.semiMajorAxisAU, $0.id.rawValue) < ($1.semiMajorAxisAU, $1.id.rawValue)
            }
            for index in 0..<(embryos.count - 1) {
                let inner = embryos[index]
                let outer = embryos[index + 1]
                let clearance = inner.orbitalClearance(to: outer, around: star.mass)
                guard clearance.mutualHillSpacing < policy.formationMergerSpacing else {
                    continue
                }
                let collision = inner.colliding(
                    with: outer,
                    retainedSolidFraction: random.uniform(in: 0.985...1),
                    retainedHydrogenHeliumFraction: random.uniform(in: 0.55...0.90)
                )
                embryos.replaceSubrange(index...(index + 1), with: [collision.remnant])
                disk.returnCollisionDebris(
                    collision.debris,
                    near: collision.remnant.semiMajorAxisAU
                )
                mergerCount += 1
                foundMerger = true
                break
            }
        }
        return mergerCount
    }

    private func gasCaptureHalfWidthAU(
        for embryo: FormationEmbryo,
        around star: GeneratedStar
    ) -> Double {
        let hillRadius = embryo.semiMajorAxisAU
            * pow(embryo.composition.totalMass.earthMasses / (3 * star.mass.earthMasses), 1.0 / 3.0)
        return max(Self.gasCaptureHillRadii * hillRadius, embryo.semiMajorAxisAU * 0.01)
    }

    private func diskGapOpeningParameter(
        for embryo: FormationEmbryo,
        around star: GeneratedStar
    ) -> Double {
        let massRatio = max(
            embryo.composition.totalMass.earthMasses / star.mass.earthMasses,
            1e-12
        )
        let aspectRatio = diskAspectRatio(
            at: embryo.semiMajorAxisAU,
            around: star
        )
        let hillRadiusAU = embryo.semiMajorAxisAU * pow(massRatio / 3, 1.0 / 3.0)
        let pressureTerm = 0.75 * aspectRatio * embryo.semiMajorAxisAU / hillRadiusAU
        let viscousTerm = 50
            * Self.diskTurbulentViscosityAlpha
            * aspectRatio * aspectRatio
            / massRatio
        return pressureTerm + viscousTerm
    }

    private func diskGapDepth(
        for embryo: FormationEmbryo,
        around star: GeneratedStar
    ) -> Double {
        let massRatio = max(
            embryo.composition.totalMass.earthMasses / star.mass.earthMasses,
            1e-12
        )
        let aspectRatio = diskAspectRatio(
            at: embryo.semiMajorAxisAU,
            around: star
        )
        let gapStrength = massRatio * massRatio
            / (Self.diskTurbulentViscosityAlpha * pow(aspectRatio, 5))
        return 1 / (1 + 0.04 * gapStrength)
    }

    private func diskAspectRatio(
        at radiusAU: Double,
        around star: GeneratedStar
    ) -> Double {
        clamped(
            0.033
                * pow(max(star.luminosity.solarLuminosities, 1e-6), 0.125)
                * pow(max(radiusAU, 0.03), 0.25)
                / sqrt(star.mass.solarMasses),
            to: 0.025...0.12
        )
    }

    private func feedingZoneHalfWidthAU(
        for embryo: FormationEmbryo,
        around star: GeneratedStar
    ) -> Double {
        let hillRadius = embryo.semiMajorAxisAU
            * pow(embryo.composition.totalMass.earthMasses / (3 * star.mass.earthMasses), 1.0 / 3.0)
        return max(8 * hillRadius, embryo.semiMajorAxisAU * 0.04)
    }

    private func nearestAnnulusIndex(to radiusAU: Double, in annuli: [FormationAnnulus]) -> Int {
        annuli.indices.min { first, second in
            abs(annuli[first].centerRadiusAU - radiusAU)
                < abs(annuli[second].centerRadiusAU - radiusAU)
        } ?? 0
    }

    private func clamped(_ value: Double, to range: ClosedRange<Double>) -> Double {
        min(max(value, range.lowerBound), range.upperBound)
    }
}
