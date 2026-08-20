/// Materializes one resolved generated star system as authoritative celestial ECS state.
///
/// The throwing initializer validates and projects immutable Game Content once.
/// ``buildWorld()`` then creates ordinary entity facades and component rows
/// without rerunning formation or retaining a live generator as Simulation
/// authority. It preserves the selected rail model as World-owned ephemeris
/// provenance. Generated stars, planets, and moons begin on source-only rails;
/// a future authority-transition path can replace one rail with integrated state.
struct GeneratedStarSystemWorldBuilder: PWorldBuilder {
    let sourceSystem: GeneratedStarSystem
    let gravitySystem: GeneratedGravitySystem

    private let initialBodyStates: [GravityBodyState]

    init(
        sourceSystem: GeneratedStarSystem,
        gravitySystemModelVersion: CelestialDynamicsModelVersion
    ) throws(GravitySystemGenerationError) {
        let gravitySystem = try GravitySystemGenerator(
            modelVersion: gravitySystemModelVersion
        ).generate(from: sourceSystem)
        let ephemeris = try GravitySystemEphemeris(system: gravitySystem)

        self.sourceSystem = sourceSystem
        self.gravitySystem = gravitySystem
        self.initialBodyStates = ephemeris.evaluatedBodyStates(
            at: gravitySystem.epoch
        )
    }

    func buildWorld() -> World {
        let world = World()
        world.celestialEphemerisConfiguration = CelestialEphemerisConfiguration(
            modelVersion: gravitySystem.modelVersion
        )
        world.celestialTimeline = CelestialTimeline(
            epoch: gravitySystem.epoch,
            predictionBasisRevision: .zero
        )
        addPrimaryStar(to: world)
        addRailBodies(to: world)
        return world
    }

    private func addPrimaryStar(to world: World) {
        let sourceStar = sourceSystem.star
        _ = Star(
            in: world,
            bodyID: .primaryStar,
            mass: gravitySystem.starMass,
            physicalRadius: gravitySystem.starRadius,
            orbitalState: .zero,
            orbitalAuthority: .ephemerisRoot,
            gravityParticipation: .sourceOnly,
            luminosity: sourceStar.luminosity,
            effectiveTemperature: sourceStar.effectiveTemperature,
            xuvLuminosityFraction: sourceStar.xuvLuminosityFraction
        )
    }

    private func addRailBodies(to world: World) {
        for bodyState in initialBodyStates {
            if bodyState.body.parentID == nil {
                addPlanet(bodyState, to: world)
            } else {
                addMoon(bodyState, to: world)
            }
        }
    }

    private func addPlanet(
        _ bodyState: GravityBodyState,
        to world: World
    ) {
        let body = bodyState.body
        _ = Planet(
            in: world,
            bodyID: celestialBodyID(for: body.id),
            mass: body.mass,
            physicalRadius: body.radius,
            orbitalState: bodyState.state,
            orbitalAuthority: .keplerianRail(
                parentID: .primaryStar,
                rail: body.rail
            ),
            gravityParticipation: .sourceOnly
        )
    }

    private func addMoon(
        _ bodyState: GravityBodyState,
        to world: World
    ) {
        let body = bodyState.body
        guard let parentID = body.parentID else {
            preconditionFailure("A validated generated moon must retain its parent identity.")
        }
        _ = Moon(
            in: world,
            bodyID: celestialBodyID(for: body.id),
            mass: body.mass,
            physicalRadius: body.radius,
            orbitalState: bodyState.state,
            orbitalAuthority: .keplerianRail(
                parentID: celestialBodyID(for: parentID),
                rail: body.rail
            ),
            gravityParticipation: .sourceOnly
        )
    }

    private func celestialBodyID(
        for generatedBodyID: GeneratedBodyID
    ) -> CelestialBodyID {
        CelestialBodyID(rawValue: generatedBodyID.rawValue)
    }
}
