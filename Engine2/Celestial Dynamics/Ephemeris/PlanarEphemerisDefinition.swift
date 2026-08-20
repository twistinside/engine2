/// Validated fixed-root hierarchy of parent-relative planar Keplerian rails.
///
/// Definitions remain in strict body-identity order. Construction rejects an
/// ambiguous root, duplicate identity, missing parent, or hierarchy cycle so
/// evaluation can recurse without fallback behavior.
nonisolated struct PlanarEphemerisDefinition: Equatable, Sendable {
    let bodies: [PlanarEphemerisBodyDefinition]

    init(
        bodies: [PlanarEphemerisBodyDefinition]
    ) throws(PlanarEphemerisError) {
        self.bodies = bodies
        try validateStableIdentityOrder()
        try validateRoot()
        let bodiesByID = Dictionary(
            uniqueKeysWithValues: bodies.map { ($0.id, $0) }
        )
        try validateParentReferences(in: bodiesByID)
        try validateAcyclicHierarchy(in: bodiesByID)
    }

    private func validateStableIdentityOrder() throws(PlanarEphemerisError) {
        var identities: Set<CelestialBodyID> = []
        for body in bodies {
            guard identities.insert(body.id).inserted else {
                throw .duplicateBodyID(body.id)
            }
        }

        for index in bodies.indices.dropFirst() {
            let previousID = bodies[index - 1].id
            let currentID = bodies[index].id
            guard previousID < currentID else {
                throw .bodiesNotOrdered(previous: previousID, current: currentID)
            }
        }
    }

    private func validateRoot() throws(PlanarEphemerisError) {
        let roots = bodies.filter { body in
            if case .root = body {
                return true
            }
            return false
        }
        guard let root = roots.first else {
            throw .missingRoot
        }
        guard roots.count == 1 else {
            throw .multipleRoots
        }
        guard root.id == .primaryStar else {
            throw .invalidRootID(root.id)
        }
    }

    private func validateParentReferences(
        in bodiesByID: [CelestialBodyID: PlanarEphemerisBodyDefinition]
    ) throws(PlanarEphemerisError) {
        for body in bodies {
            guard let parentID = body.parentID else {
                continue
            }
            guard bodiesByID[parentID] != nil else {
                throw .missingParent(body: body.id, parent: parentID)
            }
        }
    }

    private func validateAcyclicHierarchy(
        in bodiesByID: [CelestialBodyID: PlanarEphemerisBodyDefinition]
    ) throws(PlanarEphemerisError) {
        var resolvedIdentities: Set<CelestialBodyID> = []
        for body in bodies {
            var visitingIdentities: Set<CelestialBodyID> = []
            try resolveHierarchy(
                from: body.id,
                bodiesByID: bodiesByID,
                visitingIdentities: &visitingIdentities,
                resolvedIdentities: &resolvedIdentities
            )
        }
    }

    private func resolveHierarchy(
        from bodyID: CelestialBodyID,
        bodiesByID: [CelestialBodyID: PlanarEphemerisBodyDefinition],
        visitingIdentities: inout Set<CelestialBodyID>,
        resolvedIdentities: inout Set<CelestialBodyID>
    ) throws(PlanarEphemerisError) {
        guard !resolvedIdentities.contains(bodyID) else {
            return
        }
        guard visitingIdentities.insert(bodyID).inserted else {
            throw .hierarchyCycle(bodyID)
        }
        guard let body = bodiesByID[bodyID] else {
            preconditionFailure("A validated parent reference must resolve to one ephemeris body.")
        }
        if let parentID = body.parentID {
            try resolveHierarchy(
                from: parentID,
                bodiesByID: bodiesByID,
                visitingIdentities: &visitingIdentities,
                resolvedIdentities: &resolvedIdentities
            )
        }
        visitingIdentities.remove(bodyID)
        resolvedIdentities.insert(bodyID)
    }
}
