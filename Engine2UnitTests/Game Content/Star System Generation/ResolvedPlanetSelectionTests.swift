import Testing
@testable import Engine2

nonisolated struct ResolvedPlanetSelectionTests {
    private let policy = StarSystemGenerationPolicy.coreAccretionLiteV1
    private let versionOneMultiplicityWeights = [5, 9, 12, 14, 15, 15, 14, 12, 9, 5]

    @Test func everyVersionOneTicketMapsToItsExactWeightedCapacity() {
        let expectedCapacities = versionOneMultiplicityWeights.enumerated().flatMap { entry in
            Array(repeating: entry.offset, count: entry.element)
        }
        let actualCapacities = expectedCapacities.indices.map {
            ResolvedPlanetSelection.resolvedPlanetCapacity(forTicket: $0)
        }

        #expect(actualCapacities == expectedCapacities)
    }

    @Test func pinnedSeedsExposeEveryResolvedPlanetCapacity() {
        let seedsByCapacity = [43, 17, 8, 4, 0, 6, 9, 2, 11, 1]
        let capacities = seedsByCapacity.map { rawSeed in
            ResolvedPlanetSelection.resolvedPlanetCapacity(
                for: StarSystemSeed(rawValue: UInt64(rawSeed)),
                policy: policy
            )
        }

        #expect(capacities == Array(0...policy.maximumResolvedPlanetCount))
    }

    @Test func selectionRanksBySolidMassThenIdentityAndPreservesOrbitOrder() {
        let seed = StarSystemSeed(rawValue: 4)
        let embryos = [
            embryo(formationIndex: 4, semiMajorAxisAU: 0.5, solidMassEarth: 4),
            embryo(formationIndex: 0, semiMajorAxisAU: 0.8, solidMassEarth: 2),
            embryo(formationIndex: 2, semiMajorAxisAU: 1.1, solidMassEarth: 5),
            embryo(formationIndex: 1, semiMajorAxisAU: 1.4, solidMassEarth: 4),
            embryo(formationIndex: 3, semiMajorAxisAU: 1.7, solidMassEarth: 3),
            embryo(formationIndex: 5, semiMajorAxisAU: 2.0, solidMassEarth: 0.05),
            embryo(formationIndex: 6, semiMajorAxisAU: 2.3, solidMassEarth: 4)
        ]

        let selection = ResolvedPlanetSelection.select(
            from: embryos,
            seed: seed,
            policy: policy
        )

        #expect(selection.resolvedPlanetCapacity == 3)
        #expect(
            selection.embryos.map(\.id) == [
                .planet(formationIndex: 4),
                .planet(formationIndex: 2),
                .planet(formationIndex: 1)
            ]
        )
        #expect(
            selection.embryos.map(\.semiMajorAxisAU)
                == selection.embryos.map(\.semiMajorAxisAU).sorted()
        )
        expectSelectionConservesResiduals(selection, from: embryos)
    }

    @Test func zeroCapacityAggregatesEveryFormationBody() {
        let seed = StarSystemSeed(rawValue: 43)
        let embryos = [
            embryo(
                formationIndex: 0,
                semiMajorAxisAU: 0.5,
                solidMassEarth: 1,
                hydrogenHeliumEarth: 0.25,
                progenitorCount: 2
            ),
            embryo(
                formationIndex: 1,
                semiMajorAxisAU: 1,
                solidMassEarth: 2,
                hydrogenHeliumEarth: 0.5,
                progenitorCount: 3
            )
        ]

        let selection = ResolvedPlanetSelection.select(
            from: embryos,
            seed: seed,
            policy: policy
        )

        #expect(selection.resolvedPlanetCapacity == 0)
        #expect(selection.embryos.isEmpty)
        expectSelectionConservesResiduals(selection, from: embryos)
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
                iron: AstronomicalMass(earthMasses: solidMassEarth),
                silicate: .zero,
                water: .zero,
                otherVolatiles: .zero,
                hydrogenHelium: AstronomicalMass(earthMasses: hydrogenHeliumEarth)
            ),
            progenitorCount: progenitorCount
        )
    }

    private func expectSelectionConservesResiduals(
        _ selection: ResolvedPlanetSelection,
        from embryos: [FormationEmbryo]
    ) {
        let initialComposition = embryos.reduce(CelestialMassComposition.zero) {
            $0.adding($1.composition)
        }
        let selectedComposition = selection.embryos.reduce(CelestialMassComposition.zero) {
            $0.adding($1.composition)
        }
        let accountedComposition = selectedComposition.adding(selection.residualComposition)
        let initialProgenitorCount = embryos.reduce(0) { $0 + $1.progenitorCount }
        let selectedProgenitorCount = selection.embryos.reduce(0) {
            $0 + $1.progenitorCount
        }

        expectCompositionsClose(accountedComposition, initialComposition)
        #expect(selection.residualBodyCount == embryos.count - selection.embryos.count)
        #expect(
            selection.residualProgenitorCount
                == initialProgenitorCount - selectedProgenitorCount
        )
    }

    private func expectCompositionsClose(
        _ first: CelestialMassComposition,
        _ second: CelestialMassComposition
    ) {
        #expect(relativeDifference(first.iron.earthMasses, second.iron.earthMasses) < 1e-12)
        #expect(relativeDifference(first.silicate.earthMasses, second.silicate.earthMasses) < 1e-12)
        #expect(relativeDifference(first.water.earthMasses, second.water.earthMasses) < 1e-12)
        #expect(
            relativeDifference(
                first.otherVolatiles.earthMasses,
                second.otherVolatiles.earthMasses
            ) < 1e-12
        )
        #expect(
            relativeDifference(
                first.hydrogenHelium.earthMasses,
                second.hydrogenHelium.earthMasses
            ) < 1e-12
        )
    }

    private func relativeDifference(_ first: Double, _ second: Double) -> Double {
        abs(first - second) / max(abs(first), abs(second), 1)
    }
}
