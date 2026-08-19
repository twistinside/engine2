/// Projects one validated generated star system into deterministic planar rails.
///
/// The projection retains every resolved mass, radius, semimajor axis, and
/// eccentricity. It discards inclination because gameplay motion occupies one
/// physical plane, then derives orientation and phase from separately addressed
/// random streams keyed by seed, dynamics version, and stable body identity.
nonisolated struct GravitySystemGenerator: Sendable {
    let modelVersion: CelestialDynamicsModelVersion

    /// Produces and validates one complete planar rail projection.
    func generate(
        from sourceSystem: GeneratedStarSystem
    ) throws(GravitySystemGenerationError) -> GeneratedGravitySystem {
        guard modelVersion == .planarKeplerV1 else {
            throw .unsupportedDynamicsModel(modelVersion)
        }
        do {
            try sourceSystem.validate()
        } catch {
            throw .invalidSourceSystem
        }

        let epoch = CelestialEpoch.zero
        let bodies = makeBodies(
            from: sourceSystem,
            at: epoch
        )
        let gravitySystem = GeneratedGravitySystem(
            seed: sourceSystem.seed,
            modelVersion: modelVersion,
            epoch: epoch,
            starMass: sourceSystem.star.mass,
            starRadius: sourceSystem.star.radius,
            bodies: bodies
        )
        try gravitySystem.validate()
        return gravitySystem
    }

    private func makeBodies(
        from sourceSystem: GeneratedStarSystem,
        at epoch: CelestialEpoch
    ) -> [GravityRailBody] {
        var bodies: [GravityRailBody] = []
        for planet in sourceSystem.planets {
            bodies.append(
                makeBody(
                    id: planet.id,
                    parentID: nil,
                    mass: planet.mass,
                    radius: planet.radius,
                    sourceOrbit: planet.orbit,
                    primaryMass: sourceSystem.star.mass,
                    epoch: epoch,
                    seed: sourceSystem.seed
                )
            )
            for moon in planet.moons {
                bodies.append(
                    makeBody(
                        id: moon.id,
                        parentID: planet.id,
                        mass: moon.mass,
                        radius: moon.radius,
                        sourceOrbit: moon.orbit,
                        primaryMass: planet.mass,
                        epoch: epoch,
                        seed: sourceSystem.seed
                    )
                )
            }
        }
        bodies.sort { $0.id < $1.id }
        return bodies
    }

    private func makeBody(
        id: GeneratedBodyID,
        parentID: GeneratedBodyID?,
        mass: AstronomicalMass,
        radius: AstronomicalDistance,
        sourceOrbit: KeplerianOrbit,
        primaryMass: AstronomicalMass,
        epoch: CelestialEpoch,
        seed: StarSystemSeed
    ) -> GravityRailBody {
        GravityRailBody(
            id: id,
            parentID: parentID,
            mass: mass,
            radius: radius,
            rail: PlanarKeplerianRail(
                semiMajorAxis: sourceOrbit.semiMajorAxis,
                eccentricity: sourceOrbit.eccentricity,
                longitudeOfPeriapsisRadians: Self.phase(
                    seed: seed,
                    modelVersion: modelVersion,
                    bodyID: id,
                    domain: .longitudeOfPeriapsis
                ),
                meanAnomalyAtEpochRadians: Self.phase(
                    seed: seed,
                    modelVersion: modelVersion,
                    bodyID: id,
                    domain: .meanAnomalyAtEpoch
                ),
                epoch: epoch,
                gravitationalParameter: GravitationalParameter(
                    primaryMass: primaryMass,
                    orbitingMass: mass
                )
            )
        )
    }

    static func phase(
        seed: StarSystemSeed,
        modelVersion: CelestialDynamicsModelVersion,
        bodyID: GeneratedBodyID,
        domain: GravitySystemPhaseDomain
    ) -> Double {
        var key = seed.rawValue ^ domain.rawValue
        key &+= UInt64(modelVersion.rawValue) &* 0xD6E8_FEB8_6659_FD93
        key ^= bodyID.rawValue &* 0xA076_1D64_78BD_642F
        var generator = SplitMix64RandomNumberGenerator(seed: key)
        let unit = Double(generator.next() >> 11) * 0x1.0p-53
        return unit * 2 * Double.pi
    }
}
