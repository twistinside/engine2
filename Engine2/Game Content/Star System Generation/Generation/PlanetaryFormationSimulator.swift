import Foundation

/// Evolves funded embryos through bounded simultaneous accretion, gas capture, migration, and mergers.
///
/// Every epoch calculates material claims from one pre-application snapshot and
/// proportionally scales contested annuli. No embryo can gain priority merely
/// because of its array position.
nonisolated struct PlanetaryFormationSimulator: Sendable {
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
        var embryos = seedEmbryos(in: &disk, random: &placementRandom)
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
            applyInwardMigration(
                to: &embryos,
                through: disk,
                epochDurationMegayears: epochDurationMegayears
            )
            disperseGasEpoch(
                in: &disk,
                epochDurationMegayears: epochDurationMegayears,
                diskLifetimeMegayears: diskLifetimeMegayears
            )

            if (step + 1).isMultiple(of: 8) {
                formationMergerCount += mergeCloseEmbryos(
                    &embryos,
                    around: star,
                    requiredSpacing: policy.formationMergerSpacing
                )
            }
        }
        formationMergerCount += mergeCloseEmbryos(
            &embryos,
            around: star,
            requiredSpacing: policy.formationMergerSpacing
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
        random: inout StarSystemRandomStream
    ) -> [FormationEmbryo] {
        let innerEdgeAU = disk.summary.innerEdge.astronomicalUnits
        let outerEdgeAU = disk.summary.outerEdge.astronomicalUnits
        var radiusAU = innerEdgeAU * random.uniform(in: 1.25...1.45)
        var embryos: [FormationEmbryo] = []

        while radiusAU < outerEdgeAU && embryos.count < policy.maximumEmbryoCount {
            let nearestAnnulus = nearestAnnulusIndex(to: radiusAU, in: disk.annuli)
            let seedComposition = withdrawSeedComposition(
                targetMassEarth: policy.embryoSeedMassEarth,
                nearestAnnulus: nearestAnnulus,
                annuli: &disk.annuli
            )
            if seedComposition.solidMass.earthMasses > 1e-10 {
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
            radiusAU *= random.uniform(in: 1.16...1.28)
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
        guard available > 0 else {
            return .zero
        }
        let withdrawnFraction = min(targetMassEarth / available, 1)
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
            let solidMass = embryo.composition.solidMass.earthMasses
            let currentEnvelope = embryo.composition.hydrogenHelium.earthMasses
            let targetFraction = min(
                0.95,
                0.0025 * pow(max(solidMass, 1e-6), 1.7) * (1 - exp(-elapsedMegayears))
            )
            let targetEnvelope = solidMass * targetFraction / max(1 - targetFraction, 0.05)
            let captureResponse = 1 - exp(
                -5.2 * policy.gasAccretionEfficiency * epochDurationMegayears
            )
            let requestedEnvelope = max(
                0,
                (targetEnvelope - currentEnvelope) * captureResponse
            )
            guard requestedEnvelope > 0 else {
                continue
            }
            let halfWidth = feedingZoneHalfWidthAU(for: embryo, around: star)
            let localIndices = annuli.indices.filter { index in
                abs(annuli[index].centerRadiusAU - embryo.semiMajorAxisAU) <= halfWidth
            }
            let localGas = localIndices.reduce(0) { $0 + annuli[$1].remainingGasMassEarth }
            guard localGas > 0 else {
                continue
            }
            for annulusIndex in localIndices {
                let share = annuli[annulusIndex].remainingGasMassEarth / localGas
                requestedMasses[embryoIndex][annulusIndex] = requestedEnvelope * share
            }
        }
        return requestedMasses
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

    private func applyInwardMigration(
        to embryos: inout [FormationEmbryo],
        through disk: FormationDisk,
        epochDurationMegayears: Double
    ) {
        let initialGas = disk.summary.initialGasMass.earthMasses
        let remainingGas = disk.annuli.reduce(0) { $0 + $1.remainingGasMassEarth }
        let gasAvailability = initialGas > 0 ? remainingGas / initialGas : 0
        let innerTrapAU = disk.summary.innerEdge.astronomicalUnits * 1.1
        for index in embryos.indices {
            let mass = embryos[index].composition.totalMass.earthMasses
            let migrationRatePerMegayear = 0.384
                * policy.migrationEfficiency
                * mass / (1 + mass / 30)
                * gasAvailability
            let fractionalStep = min(
                0.03,
                1 - exp(-migrationRatePerMegayear * epochDurationMegayears)
            )
            embryos[index].semiMajorAxisAU = max(
                innerTrapAU,
                embryos[index].semiMajorAxisAU * (1 - fractionalStep)
            )
        }
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

    private func mergeCloseEmbryos(
        _ embryos: inout [FormationEmbryo],
        around star: GeneratedStar,
        requiredSpacing: Double
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
                guard clearance.mutualHillSpacing < requiredSpacing else {
                    continue
                }
                embryos.replaceSubrange(index...(index + 1), with: [inner.merging(with: outer)])
                mergerCount += 1
                foundMerger = true
                break
            }
        }
        return mergerCount
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
}
