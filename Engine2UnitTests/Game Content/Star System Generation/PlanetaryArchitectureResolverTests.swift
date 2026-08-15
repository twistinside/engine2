import Foundation
import Testing
@testable import Engine2

nonisolated struct PlanetaryArchitectureResolverTests {
    private let policy = StarSystemGenerationPolicy.coreAccretionLiteV1

    @Test func stableArchitecturePassesThroughWithoutDynamicalLoss() {
        let star = MainSequenceStarGenerator(policy: policy).generate(
            seed: StarSystemSeed(rawValue: 201)
        )
        let original = [
            embryo(formationIndex: 0, semiMajorAxisAU: 1, solidMassEarth: 1),
            embryo(formationIndex: 1, semiMajorAxisAU: 2, solidMassEarth: 1)
        ]
        var resolved = original

        let outcome = PlanetaryArchitectureResolver(policy: policy).resolve(
            &resolved,
            around: star,
            within: 0.03...40,
            seed: StarSystemSeed(rawValue: 201)
        )

        #expect(resolved.count == original.count)
        #expect(resolved.map(\.id) == original.map(\.id))
        #expect(resolved.map(\.semiMajorAxisAU) == original.map(\.semiMajorAxisAU))
        #expect(resolved.map(\.composition) == original.map(\.composition))
        #expect(outcome.collisionMergerCount == 0)
        #expect(outcome.scatteringCount == 0)
        #expect(outcome.ejectedBodyCount == 0)
        #expect(outcome.starAccretedBodyCount == 0)
        #expect(outcome.ejectedComposition == .zero)
        #expect(outcome.starAccretedComposition == .zero)
        #expect(outcome.collisionDebrisComposition == .zero)
    }

    @Test func collisionConservesEveryComponentAndProgenitor() {
        let first = embryo(
            formationIndex: 0,
            semiMajorAxisAU: 1,
            solidMassEarth: 2,
            hydrogenHeliumEarth: 0.2,
            progenitorCount: 2
        )
        let second = embryo(
            formationIndex: 1,
            semiMajorAxisAU: 1.01,
            solidMassEarth: 3,
            hydrogenHeliumEarth: 0.4,
            progenitorCount: 3
        )
        let initialComposition = first.composition.adding(second.composition)

        let collision = first.colliding(
            with: second,
            retainedSolidFraction: 0.91,
            retainedHydrogenHeliumFraction: 0.35
        )
        let accountedComposition = collision.remnant.composition.adding(collision.debris)

        expectCompositionsClose(accountedComposition, initialComposition)
        #expect(collision.remnant.id == first.id)
        #expect(collision.remnant.progenitorCount == 5)
        #expect(collision.debris.solidMass > .zero)
        #expect(collision.debris.hydrogenHelium > .zero)
    }

    @Test func encounterOutcomesRemainConservedAndExerciseAllModes() {
        let star = MainSequenceStarGenerator(policy: policy).generate(
            seed: StarSystemSeed(rawValue: 202)
        )
        var sawCollision = false
        var sawScattering = false
        var sawEjection = false
        var sawStellarAccretion = false

        for rawSeed in 0..<256 {
            for original in encounterArchitectures() {
                var resolved = original
                let outcome = PlanetaryArchitectureResolver(policy: policy).resolve(
                    &resolved,
                    around: star,
                    within: 0.03...40,
                    seed: StarSystemSeed(rawValue: UInt64(rawSeed))
                )

                expectConservedResolution(
                    original: original,
                    resolved: resolved,
                    outcome: outcome
                )
                sawCollision = sawCollision || outcome.collisionMergerCount > 0
                sawScattering = sawScattering || outcome.scatteringCount > 0
                sawEjection = sawEjection || outcome.ejectedBodyCount > 0
                sawStellarAccretion = sawStellarAccretion || outcome.starAccretedBodyCount > 0
            }
            if sawCollision && sawScattering && sawEjection && sawStellarAccretion {
                break
            }
        }

        #expect(sawCollision)
        #expect(sawScattering)
        #expect(sawEjection)
        #expect(sawStellarAccretion)
    }

    private func encounterArchitectures() -> [[FormationEmbryo]] {
        [
            [
                embryo(formationIndex: 0, semiMajorAxisAU: 0.05, solidMassEarth: 1),
                embryo(formationIndex: 1, semiMajorAxisAU: 0.050_001, solidMassEarth: 1)
            ],
            [
                embryo(formationIndex: 0, semiMajorAxisAU: 1, solidMassEarth: 1),
                embryo(formationIndex: 1, semiMajorAxisAU: 1.000_01, solidMassEarth: 1)
            ],
            [
                embryo(
                    formationIndex: 0,
                    semiMajorAxisAU: 5,
                    solidMassEarth: 50,
                    hydrogenHeliumEarth: 50
                ),
                embryo(
                    formationIndex: 1,
                    semiMajorAxisAU: 5.000_01,
                    solidMassEarth: 50,
                    hydrogenHeliumEarth: 50
                )
            ]
        ]
    }

    private func embryo(
        formationIndex: Int,
        semiMajorAxisAU: Double,
        solidMassEarth: Double,
        hydrogenHeliumEarth: Double = 0,
        progenitorCount: Int = 1
    ) -> FormationEmbryo {
        FormationEmbryo(
            id: .planet(formationIndex: formationIndex),
            semiMajorAxisAU: semiMajorAxisAU,
            eccentricity: 0,
            inclinationDegrees: 0,
            composition: CelestialMassComposition(
                iron: AstronomicalMass(earthMasses: solidMassEarth * 0.32),
                silicate: AstronomicalMass(earthMasses: solidMassEarth * 0.63),
                water: AstronomicalMass(earthMasses: solidMassEarth * 0.04),
                otherVolatiles: AstronomicalMass(earthMasses: solidMassEarth * 0.01),
                hydrogenHelium: AstronomicalMass(earthMasses: hydrogenHeliumEarth)
            ),
            progenitorCount: progenitorCount
        )
    }

    private func expectConservedResolution(
        original: [FormationEmbryo],
        resolved: [FormationEmbryo],
        outcome: PlanetaryArchitectureResolution
    ) {
        let initialComposition = original.reduce(CelestialMassComposition.zero) {
            $0.adding($1.composition)
        }
        let retainedComposition = resolved.reduce(CelestialMassComposition.zero) {
            $0.adding($1.composition)
        }
        let accountedComposition = retainedComposition
            .adding(outcome.ejectedComposition)
            .adding(outcome.starAccretedComposition)
            .adding(outcome.collisionDebrisComposition)
        let initialProgenitorCount = original.reduce(0) { $0 + $1.progenitorCount }
        let retainedProgenitorCount = resolved.reduce(0) { $0 + $1.progenitorCount }
        let removedBodyCount = outcome.ejectedBodyCount + outcome.starAccretedBodyCount

        expectCompositionsClose(accountedComposition, initialComposition)
        #expect(
            retainedProgenitorCount
                + outcome.ejectedProgenitorCount
                + outcome.starAccretedProgenitorCount == initialProgenitorCount
        )
        #expect(resolved.count == original.count - outcome.collisionMergerCount - removedBodyCount)
    }

    private func expectCompositionsClose(
        _ first: CelestialMassComposition,
        _ second: CelestialMassComposition
    ) {
        #expect(relativeDifference(first.iron.earthMasses, second.iron.earthMasses) < 1e-12)
        #expect(relativeDifference(first.silicate.earthMasses, second.silicate.earthMasses) < 1e-12)
        #expect(relativeDifference(first.water.earthMasses, second.water.earthMasses) < 1e-12)
        #expect(relativeDifference(first.otherVolatiles.earthMasses, second.otherVolatiles.earthMasses) < 1e-12)
        #expect(
            relativeDifference(first.hydrogenHelium.earthMasses, second.hydrogenHelium.earthMasses) < 1e-12
        )
    }

    private func relativeDifference(_ first: Double, _ second: Double) -> Double {
        abs(first - second) / max(abs(first), abs(second), 1)
    }
}
