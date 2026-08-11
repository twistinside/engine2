/// Deterministic construction-time generator for one physically derived star system.
///
/// The generator is synchronous, value-semantic, and side-effect free. It owns
/// no Runtime lifecycle or cadence and does not mutate ECS state. Callers persist
/// the returned resolved value rather than relying on seed-only regeneration.
/// Bodies omitted by resolved-planet significance or multiplicity remain
/// aggregated in the formation ledger instead of receiving invented details.
nonisolated struct StarSystemGenerator: Sendable {
    let policy: StarSystemGenerationPolicy

    /// Generates and validates one system using the complete injected policy.
    func generate(seed: StarSystemSeed) throws(StarSystemGenerationError) -> GeneratedStarSystem {
        guard policy.isValid, policy.isSupportedCalibration else {
            throw .invalidPolicy
        }
        let star = MainSequenceStarGenerator(policy: policy).generate(seed: seed)
        let initialDisk = ProtoplanetaryDiskGenerator(policy: policy).generate(
            around: star,
            seed: seed
        )
        var formation = try PlanetaryFormationSimulator(policy: policy).formPlanets(
            in: initialDisk,
            around: star,
            seed: seed
        )
        let diskOrbitalRangeAU = formation.disk.summary.innerEdge.astronomicalUnits
            ... formation.disk.summary.outerEdge.astronomicalUnits
        let architecture = PlanetaryArchitectureResolver(policy: policy).resolve(
            &formation.embryos,
            around: star,
            within: diskOrbitalRangeAU,
            seed: seed
        )
        let selection = ResolvedPlanetSelection.select(
            from: formation.embryos,
            seed: seed,
            policy: policy
        )
        let resolved = resolvePresentDayPlanets(
            selection.embryos,
            around: star,
            seed: seed
        )
        let ledger = makeFormationLedger(
            formation: formation,
            planets: resolved.planets,
            escapedHydrogenHeliumMassEarth: resolved.escapedHydrogenHeliumMassEarth,
            architecture: architecture,
            selection: selection
        )
        let system = GeneratedStarSystem(
            seed: seed,
            modelVersion: policy.modelVersion,
            policy: policy,
            star: star,
            protoplanetaryDisk: formation.disk.summary,
            formationLedger: ledger,
            planets: resolved.planets
        )
        try system.validate()
        return system
    }

    private func resolvePresentDayPlanets(
        _ embryos: [FormationEmbryo],
        around star: GeneratedStar,
        seed: StarSystemSeed
    ) -> (planets: [GeneratedPlanet], escapedHydrogenHeliumMassEarth: Double) {
        let environmentResolver = PlanetaryEnvironmentResolver(policy: policy)
        let moonGenerator = MoonSystemGenerator(
            policy: policy,
            environmentResolver: environmentResolver
        )
        var planets: [GeneratedPlanet] = []
        var escapedHydrogenHeliumMassEarth = 0.0

        for sourceEmbryo in embryos {
            var embryo = sourceEmbryo
            let moonSeeds = moonGenerator.extractMoonSeeds(
                from: &embryo,
                around: star,
                seed: seed
            )
            let orbit = KeplerianOrbit(
                semiMajorAxis: AstronomicalDistance(astronomicalUnits: embryo.semiMajorAxisAU),
                eccentricity: OrbitalEccentricity(rawValue: embryo.eccentricity),
                inclinationDegrees: embryo.inclinationDegrees
            )
            let evolvedPlanet = environmentResolver.resolve(
                composition: embryo.composition,
                orbit: orbit,
                around: star
            )
            let moons = moonGenerator.resolveMoons(
                moonSeeds,
                around: evolvedPlanet,
                on: orbit,
                star: star,
                rootSeed: seed
            )
            escapedHydrogenHeliumMassEarth += evolvedPlanet.escapedHydrogenHeliumMass.earthMasses
            planets.append(
                GeneratedPlanet(
                    id: embryo.id,
                    composition: evolvedPlanet.composition,
                    radius: evolvedPlanet.radius,
                    orbit: orbit,
                    environment: evolvedPlanet.environment,
                    physicalState: evolvedPlanet.physicalState,
                    moons: moons,
                    progenitorCount: embryo.progenitorCount
                )
            )
        }
        planets.sort { $0.orbit.semiMajorAxis < $1.orbit.semiMajorAxis }
        return (planets, escapedHydrogenHeliumMassEarth)
    }

    private func makeFormationLedger(
        formation: PlanetaryFormationResult,
        planets: [GeneratedPlanet],
        escapedHydrogenHeliumMassEarth: Double,
        architecture: PlanetaryArchitectureResolution,
        selection: ResolvedPlanetSelection
    ) -> StarSystemFormationLedger {
        let compositions = planets.flatMap { planet in
            [planet.composition] + planet.moons.map(\.composition)
        }
        let retainedSolidMassEarth = compositions.reduce(0) { $0 + $1.solidMass.earthMasses }
        let retainedHydrogenHeliumMassEarth = compositions.reduce(0) {
            $0 + $1.hydrogenHelium.earthMasses
        }
        let unaccretedSolidMassEarth = formation.disk.annuli.reduce(0) {
            $0 + $1.remainingSolidMassEarth
        }
        let unaccretedSolidComposition = formation.disk.annuli.reduce(CelestialMassComposition.zero) {
            $0.adding($1.solidComposition)
        }
        return StarSystemFormationLedger(
            initialSolidMass: formation.disk.summary.initialSolidMass,
            retainedSolidMass: AstronomicalMass(earthMasses: retainedSolidMassEarth),
            unaccretedSolidMass: AstronomicalMass(earthMasses: unaccretedSolidMassEarth),
            unaccretedSolidComposition: unaccretedSolidComposition,
            initialGasMass: formation.disk.summary.initialGasMass,
            retainedHydrogenHeliumMass: AstronomicalMass(earthMasses: retainedHydrogenHeliumMassEarth),
            escapedHydrogenHeliumMass: AstronomicalMass(earthMasses: escapedHydrogenHeliumMassEarth),
            dispersedGasMass: AstronomicalMass(earthMasses: formation.disk.dispersedGasMassEarth),
            dynamicalLosses: StarSystemDynamicalLossLedger(
                ejectedComposition: architecture.ejectedComposition,
                starAccretedComposition: architecture.starAccretedComposition,
                collisionDebrisComposition: architecture.collisionDebrisComposition,
                scatteringCount: architecture.scatteringCount,
                ejectedBodyCount: architecture.ejectedBodyCount,
                ejectedProgenitorCount: architecture.ejectedProgenitorCount,
                starAccretedBodyCount: architecture.starAccretedBodyCount,
                starAccretedProgenitorCount: architecture.starAccretedProgenitorCount
            ),
            residualBodyComposition: selection.residualComposition,
            residualBodyCount: selection.residualBodyCount,
            residualProgenitorCount: selection.residualProgenitorCount,
            resolvedPlanetCapacity: selection.resolvedPlanetCapacity,
            seededEmbryoCount: formation.seededEmbryoCount,
            formationMergerCount: formation.formationMergerCount,
            postDiskCollisionMergerCount: architecture.collisionMergerCount
        )
    }
}
