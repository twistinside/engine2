/// Evaluates absolute generated-body states from one validated rail hierarchy.
///
/// Planet states are relative to the star at the origin. Moon states compose
/// their parent planet's absolute state with the moon's parent-relative rail.
/// Complete evaluations preserve the system's stable body-identity order.
nonisolated struct GravitySystemEphemeris: Sendable {
    let system: GeneratedGravitySystem

    private let evaluator: PlanarEphemerisEvaluator

    init(
        system: GeneratedGravitySystem,
        kernel: PlanarKeplerPropagationKernel = PlanarKeplerPropagationKernel()
    ) throws(GravitySystemGenerationError) {
        try system.validate()
        self.system = system
        let definition: PlanarEphemerisDefinition
        do {
            definition = try Self.makeDefinition(for: system)
        } catch {
            preconditionFailure(
                "Validated generated gravity state must form one planar ephemeris: \(error)"
            )
        }
        self.evaluator = PlanarEphemerisEvaluator(
            definition: definition,
            kernel: kernel
        )
    }

    /// Evaluates every generated body in stable identity order.
    func evaluatedBodyStates(at epoch: CelestialEpoch) -> [GravityBodyState] {
        let evaluatedStates: [PlanarOrbitalBodyState]
        do {
            evaluatedStates = try evaluator.states(at: epoch)
        } catch {
            preconditionFailure(
                "A validated generated ephemeris must produce finite body states: \(error)"
            )
        }
        let generatedStates = evaluatedStates.dropFirst()
        precondition(
            generatedStates.count == system.bodies.count,
            "The generated ephemeris must return one state for every rail body."
        )
        return zip(system.bodies, generatedStates).map { body, evaluatedState in
            precondition(
                evaluatedState.id == Self.celestialBodyID(for: body.id),
                "The generated ephemeris must preserve stable body order."
            )
            return GravityBodyState(body: body, state: evaluatedState.state)
        }
    }

    private static func makeDefinition(
        for system: GeneratedGravitySystem
    ) throws(PlanarEphemerisError) -> PlanarEphemerisDefinition {
        var definitions: [PlanarEphemerisBodyDefinition] = [
            .root(id: .primaryStar, state: .zero)
        ]
        definitions.reserveCapacity(system.bodies.count + 1)
        for body in system.bodies {
            definitions.append(
                .parentRelativeRail(
                    id: Self.celestialBodyID(for: body.id),
                    parentID: body.parentID.map(Self.celestialBodyID(for:))
                        ?? .primaryStar,
                    rail: body.rail
                )
            )
        }
        return try PlanarEphemerisDefinition(bodies: definitions)
    }

    private static func celestialBodyID(
        for generatedBodyID: GeneratedBodyID
    ) -> CelestialBodyID {
        CelestialBodyID(rawValue: generatedBodyID.rawValue)
    }
}
