import Foundation

/// Resolves post-disk encounters into bounded collisions, scattering, ejections, and stellar loss.
///
/// The analytic mutual-Hill filter triggers an encounter; it does not imply a
/// collision. Removed and collision-stripped compositions remain explicit so
/// the caller can close the generated system's conservation ledger.
nonisolated struct PlanetaryArchitectureResolver: Sendable {
    let policy: StarSystemGenerationPolicy

    func resolve(
        _ embryos: inout [FormationEmbryo],
        around star: GeneratedStar,
        within orbitalRangeAU: ClosedRange<Double>,
        seed: StarSystemSeed
    ) -> PlanetaryArchitectureResolution {
        precondition(
            orbitalRangeAU.lowerBound.isFinite
                && orbitalRangeAU.upperBound.isFinite
                && orbitalRangeAU.lowerBound > star.radius.astronomicalUnits
                && orbitalRangeAU.upperBound > orbitalRangeAU.lowerBound,
            "Dynamical clearing requires a finite disk orbital range outside the star."
        )
        var resolution = PlanetaryArchitectureResolution.empty
        clearInsufficientlySpacedPairs(
            &embryos,
            around: star,
            within: orbitalRangeAU,
            seed: seed,
            resolution: &resolution
        )
        assignOrbitalExcitation(to: &embryos, seed: seed)
        dampEccentricitiesUntilRadiallyClear(&embryos, around: star)
        embryos.sort {
            ($0.semiMajorAxisAU, $0.id.rawValue) < ($1.semiMajorAxisAU, $1.id.rawValue)
        }
        return resolution
    }

    private func clearInsufficientlySpacedPairs(
        _ embryos: inout [FormationEmbryo],
        around star: GeneratedStar,
        within orbitalRangeAU: ClosedRange<Double>,
        seed: StarSystemSeed,
        resolution: inout PlanetaryArchitectureResolution
    ) {
        for encounterSequence in 0..<policy.maximumPostDiskEncounterCount {
            embryos.sort {
                ($0.semiMajorAxisAU, $0.id.rawValue) < ($1.semiMajorAxisAU, $1.id.rawValue)
            }
            guard let innerIndex = firstInsufficientlySpacedPairIndex(
                in: embryos,
                around: star
            ) else {
                return
            }
            resolveEncounter(
                at: innerIndex,
                in: &embryos,
                around: star,
                within: orbitalRangeAU,
                seed: seed,
                sequence: encounterSequence,
                resolution: &resolution
            )
        }
        ejectSmallerBodiesUntilSpaced(
            &embryos,
            around: star,
            resolution: &resolution
        )
    }

    private func firstInsufficientlySpacedPairIndex(
        in embryos: [FormationEmbryo],
        around star: GeneratedStar
    ) -> Int? {
        guard embryos.count > 1 else {
            return nil
        }
        for index in 0..<(embryos.count - 1) {
            let inner = embryos[index]
            let outer = embryos[index + 1]
            let requiredSpacing = policy.requiredFinalSpacing(
                between: inner.composition.totalMass,
                and: outer.composition.totalMass
            )
            if inner.orbitalClearance(to: outer, around: star.mass).mutualHillSpacing < requiredSpacing {
                return index
            }
        }
        return nil
    }

    private func resolveEncounter(
        at innerIndex: Int,
        in embryos: inout [FormationEmbryo],
        around star: GeneratedStar,
        within orbitalRangeAU: ClosedRange<Double>,
        seed: StarSystemSeed,
        sequence: Int,
        resolution: inout PlanetaryArchitectureResolution
    ) {
        let outerIndex = innerIndex + 1
        let inner = embryos[innerIndex]
        let outer = embryos[outerIndex]
        let requiredSpacing = policy.requiredFinalSpacing(
            between: inner.composition.totalMass,
            and: outer.composition.totalMass
        )
        let clearance = inner.orbitalClearance(to: outer, around: star.mass)
        let spacingSeverity = min(
            1,
            max(0, (requiredSpacing - clearance.mutualHillSpacing) / requiredSpacing)
        )
        let escapeToOrbitSpeedSquaredRatio = encounterEscapeToOrbitSpeedSquaredRatio(
            inner: inner,
            outer: outer,
            around: star
        )
        var random = StarSystemRandomStream(
            seed: seed,
            modelVersion: policy.modelVersion,
            domain: .dynamicalClearing,
            discriminator: encounterDiscriminator(
                inner: inner.id,
                outer: outer.id,
                sequence: sequence
            )
        )
        let stellarProximity = min(
            1,
            0.1 / max(inner.semiMajorAxisAU, 0.01)
        )
        let stellarAccretionProbability = min(
            0.12,
            0.015 + 0.08 * spacingSeverity * stellarProximity
        )
        let ejectionProbability = min(
            0.72,
            max(0, (escapeToOrbitSpeedSquaredRatio - 0.8) / 4) * spacingSeverity
        )
        let collisionProbability = min(
            0.55,
            0.18 + 0.38 / (1 + escapeToOrbitSpeedSquaredRatio)
        )
        let outcome = random.uniformUnit()
        let ejectionThreshold = stellarAccretionProbability
            + (1 - stellarAccretionProbability) * ejectionProbability
        let collisionThreshold = ejectionThreshold
            + (1 - ejectionThreshold) * collisionProbability

        if outcome < stellarAccretionProbability {
            resolution.recordStellarAccretion(embryos.remove(at: innerIndex))
            return
        }
        if outcome < ejectionThreshold {
            let ejectedIndex = ejectionIndex(
                innerIndex: innerIndex,
                outerIndex: outerIndex,
                embryos: embryos,
                random: &random
            )
            resolution.recordEjection(embryos.remove(at: ejectedIndex))
            return
        }
        if outcome < collisionThreshold {
            resolveCollision(
                at: innerIndex,
                in: &embryos,
                severity: spacingSeverity,
                random: &random,
                resolution: &resolution
            )
            return
        }
        if scatterPairApart(
            at: innerIndex,
            in: &embryos,
            around: star,
            within: orbitalRangeAU,
            requiredSpacing: requiredSpacing
        ) {
            resolution.recordScattering()
            return
        }
        resolveCollision(
            at: innerIndex,
            in: &embryos,
            severity: spacingSeverity,
            random: &random,
            resolution: &resolution
        )
    }

    private func resolveCollision(
        at innerIndex: Int,
        in embryos: inout [FormationEmbryo],
        severity: Double,
        random: inout StarSystemRandomStream,
        resolution: inout PlanetaryArchitectureResolution
    ) {
        let collision = embryos[innerIndex].colliding(
            with: embryos[innerIndex + 1],
            retainedSolidFraction: max(
                0.90,
                0.995 - 0.08 * severity * random.uniform(in: 0.5...1)
            ),
            retainedHydrogenHeliumFraction: max(
                0.15,
                0.80 - 0.60 * severity * random.uniform(in: 0.5...1)
            )
        )
        embryos.replaceSubrange(innerIndex...(innerIndex + 1), with: [collision.remnant])
        resolution.recordCollision(debris: collision.debris)
    }

    private func ejectionIndex(
        innerIndex: Int,
        outerIndex: Int,
        embryos: [FormationEmbryo],
        random: inout StarSystemRandomStream
    ) -> Int {
        let innerMass = embryos[innerIndex].composition.totalMass.earthMasses
        let outerMass = embryos[outerIndex].composition.totalMass.earthMasses
        if innerMass == outerMass {
            return random.uniformUnit() < 0.5 ? innerIndex : outerIndex
        }
        return innerMass < outerMass ? innerIndex : outerIndex
    }

    private func scatterPairApart(
        at innerIndex: Int,
        in embryos: inout [FormationEmbryo],
        around star: GeneratedStar,
        within orbitalRangeAU: ClosedRange<Double>,
        requiredSpacing: Double
    ) -> Bool {
        let inner = embryos[innerIndex]
        let outer = embryos[innerIndex + 1]
        let innerMass = inner.composition.totalMass.earthMasses
        let outerMass = outer.composition.totalMass.earthMasses
        let circularAngularMomentum = innerMass * sqrt(inner.semiMajorAxisAU)
            + outerMass * sqrt(outer.semiMajorAxisAU)
        let currentClearance = inner.orbitalClearance(to: outer, around: star.mass)
        let requiredSeparationAU = 1.05 * requiredSpacing * currentClearance.mutualHillRadius
        let separationDeficitAU = max(
            0,
            requiredSeparationAU - (outer.semiMajorAxisAU - inner.semiMajorAxisAU)
        )
        let minimumOrbitAU = orbitalRangeAU.lowerBound * 1.001

        for expansion in [1.0, 1.25, 1.5, 2.0] {
            let candidateInnerAxisAU = max(
                minimumOrbitAU,
                inner.semiMajorAxisAU
                    - expansion * separationDeficitAU * outerMass / (innerMass + outerMass)
            )
            let remainingAngularMomentum = circularAngularMomentum
                - innerMass * sqrt(candidateInnerAxisAU)
            guard remainingAngularMomentum > 0 else {
                continue
            }
            let candidateOuterAxisAU = pow(remainingAngularMomentum / outerMass, 2)
            guard candidateOuterAxisAU < orbitalRangeAU.upperBound * 0.999 else {
                continue
            }
            var candidateInner = inner
            var candidateOuter = outer
            candidateInner.semiMajorAxisAU = candidateInnerAxisAU
            candidateOuter.semiMajorAxisAU = candidateOuterAxisAU
            candidateInner.eccentricity = 0
            candidateOuter.eccentricity = 0
            let candidateClearance = candidateInner.orbitalClearance(
                to: candidateOuter,
                around: star.mass
            )
            guard candidateClearance.mutualHillSpacing >= requiredSpacing else {
                continue
            }
            embryos[innerIndex] = candidateInner
            embryos[innerIndex + 1] = candidateOuter
            return true
        }
        return false
    }

    private func encounterEscapeToOrbitSpeedSquaredRatio(
        inner: FormationEmbryo,
        outer: FormationEmbryo,
        around star: GeneratedStar
    ) -> Double {
        let combinedMassEarth = inner.composition.totalMass.earthMasses
            + outer.composition.totalMass.earthMasses
        let combinedRadiusAU = AstronomicalDistance(
            earthRadii: inner.estimatedRadiusEarthRadii + outer.estimatedRadiusEarthRadii
        ).astronomicalUnits
        let meanAxisAU = (inner.semiMajorAxisAU + outer.semiMajorAxisAU) / 2
        return 2
            * combinedMassEarth / star.mass.earthMasses
            * meanAxisAU / combinedRadiusAU
    }

    private func encounterDiscriminator(
        inner: GeneratedBodyID,
        outer: GeneratedBodyID,
        sequence: Int
    ) -> UInt64 {
        inner.rawValue
            ^ (outer.rawValue &* 0x9E37_79B9_7F4A_7C15)
            ^ (UInt64(sequence) &* 0xBF58_476D_1CE4_E5B9)
    }

    private func ejectSmallerBodiesUntilSpaced(
        _ embryos: inout [FormationEmbryo],
        around star: GeneratedStar,
        resolution: inout PlanetaryArchitectureResolution
    ) {
        embryos.sort {
            ($0.semiMajorAxisAU, $0.id.rawValue) < ($1.semiMajorAxisAU, $1.id.rawValue)
        }
        while let innerIndex = firstInsufficientlySpacedPairIndex(in: embryos, around: star) {
            let outerIndex = innerIndex + 1
            let innerMass = embryos[innerIndex].composition.totalMass.earthMasses
            let outerMass = embryos[outerIndex].composition.totalMass.earthMasses
            let ejectedIndex = innerMass <= outerMass ? innerIndex : outerIndex
            resolution.recordEjection(embryos.remove(at: ejectedIndex))
        }
    }

    private func assignOrbitalExcitation(
        to embryos: inout [FormationEmbryo],
        seed: StarSystemSeed
    ) {
        for index in embryos.indices {
            var random = StarSystemRandomStream(
                seed: seed,
                modelVersion: policy.modelVersion,
                domain: .orbitalExcitation,
                discriminator: embryos[index].id.rawValue
            )
            let isDynamicallyHot = embryos[index].progenitorCount >= 4
                || embryos[index].composition.totalMass.earthMasses >= policy.giantMassThresholdEarth
            embryos[index].eccentricity = min(random.rayleigh(scale: isDynamicallyHot ? 0.05 : 0.02), 0.18)
            embryos[index].inclinationDegrees = min(abs(random.normal(standardDeviation: 0.8)), 5)
        }
    }

    private func dampEccentricitiesUntilRadiallyClear(
        _ embryos: inout [FormationEmbryo],
        around star: GeneratedStar
    ) {
        embryos.sort {
            ($0.semiMajorAxisAU, $0.id.rawValue) < ($1.semiMajorAxisAU, $1.id.rawValue)
        }
        for _ in 0..<32 {
            guard !containsRadiallyUnclearPair(embryos, centralMass: star.mass) else {
                for index in embryos.indices {
                    embryos[index].eccentricity *= 0.8
                }
                continue
            }
            return
        }
        for index in embryos.indices {
            embryos[index].eccentricity = 0
        }
    }

    private func containsRadiallyUnclearPair(
        _ embryos: [FormationEmbryo],
        centralMass: AstronomicalMass
    ) -> Bool {
        guard embryos.count > 1 else {
            return false
        }
        for index in 0..<(embryos.count - 1) {
            let inner = embryos[index]
            let outer = embryos[index + 1]
            let clearance = inner.orbitalClearance(
                to: outer,
                around: centralMass
            )
            if !policy.acceptsRadialClearance(clearance) {
                return true
            }
        }
        return false
    }
}
