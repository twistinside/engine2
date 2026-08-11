import Foundation

/// Deterministically merges post-disk neighbors until conservative spacing is satisfied.
///
/// The analytic mutual-Hill filter is a construction rule, not a proof of
/// gigayear N-body stability. V1 merges unstable pairs instead of inventing an
/// unmodeled scattering or ejection history.
nonisolated struct PlanetaryArchitectureResolver: Sendable {
    let policy: StarSystemGenerationPolicy

    func resolve(
        _ embryos: inout [FormationEmbryo],
        around star: GeneratedStar,
        seed: StarSystemSeed
    ) -> Int {
        let mergerCount = clearInsufficientlySpacedPairs(&embryos, around: star)
        assignOrbitalExcitation(to: &embryos, seed: seed)
        dampEccentricitiesUntilRadiallyClear(&embryos, around: star)
        embryos.sort {
            ($0.semiMajorAxisAU, $0.id.rawValue) < ($1.semiMajorAxisAU, $1.id.rawValue)
        }
        return mergerCount
    }

    private func clearInsufficientlySpacedPairs(
        _ embryos: inout [FormationEmbryo],
        around star: GeneratedStar
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
                let requiredSpacing = policy.requiredFinalSpacing(
                    between: inner.composition.totalMass,
                    and: outer.composition.totalMass
                )
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
