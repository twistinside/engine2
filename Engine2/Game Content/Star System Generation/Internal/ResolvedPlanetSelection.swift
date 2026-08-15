/// Formation bodies selected for detailed planet output and the aggregated residual population.
///
/// V1 samples one bounded resolved-planet capacity, then selects the most
/// significant eligible survivors. Every omission remains conserved in the
/// residual ledger without receiving invented detailed facts.
nonisolated struct ResolvedPlanetSelection: Sendable {
    private static let versionOneMultiplicityWeights = [5, 9, 12, 14, 15, 15, 14, 12, 9, 5]

    let embryos: [FormationEmbryo]
    let residualComposition: CelestialMassComposition
    let residualBodyCount: Int
    let residualProgenitorCount: Int
    let resolvedPlanetCapacity: Int

    static func select(
        from embryos: [FormationEmbryo],
        seed: StarSystemSeed,
        policy: StarSystemGenerationPolicy
    ) -> ResolvedPlanetSelection {
        let capacity = resolvedPlanetCapacity(for: seed, policy: policy)
        let eligible = embryos.filter {
            $0.composition.solidMass.earthMasses
                >= policy.minimumResolvedPlanetSolidMassEarth
        }
        let selectedIdentities = Set(
            eligible.sorted(by: isMoreSignificant)
                .prefix(capacity)
                .map(\.id)
        )
        let selected = embryos.filter { selectedIdentities.contains($0.id) }
        let residual = embryos.filter { !selectedIdentities.contains($0.id) }
        return ResolvedPlanetSelection(
            embryos: selected,
            residualComposition: residual.reduce(.zero) {
                $0.adding($1.composition)
            },
            residualBodyCount: residual.count,
            residualProgenitorCount: residual.reduce(0) { $0 + $1.progenitorCount },
            resolvedPlanetCapacity: capacity
        )
    }

    static func resolvedPlanetCapacity(
        for seed: StarSystemSeed,
        policy: StarSystemGenerationPolicy
    ) -> Int {
        precondition(
            policy.maximumResolvedPlanetCount == versionOneMultiplicityWeights.count - 1,
            "The resolved-planet multiplicity weights must cover the policy capacity."
        )
        var random = StarSystemRandomStream(
            seed: seed,
            modelVersion: policy.modelVersion,
            domain: .resolvedPlanetMultiplicity
        )
        let ticket = random.integer(
            in: 0...(versionOneMultiplicityWeights.reduce(0, +) - 1)
        )
        return resolvedPlanetCapacity(forTicket: ticket)
    }

    static func resolvedPlanetCapacity(forTicket ticket: Int) -> Int {
        precondition(
            (0..<versionOneMultiplicityWeights.reduce(0, +)).contains(ticket),
            "The resolved-planet multiplicity ticket must be inside its weight table."
        )
        var remainingTicket = ticket
        for (count, weight) in versionOneMultiplicityWeights.enumerated() {
            if remainingTicket < weight {
                return count
            }
            remainingTicket -= weight
        }
        preconditionFailure("The resolved-planet multiplicity ticket exceeded its weight table.")
    }

    private static func isMoreSignificant(
        _ first: FormationEmbryo,
        _ second: FormationEmbryo
    ) -> Bool {
        let firstMass = first.composition.solidMass.earthMasses
        let secondMass = second.composition.solidMass.earthMasses
        if firstMass != secondMass {
            return firstMass > secondMass
        }
        return first.id.rawValue < second.id.rawValue
    }
}
