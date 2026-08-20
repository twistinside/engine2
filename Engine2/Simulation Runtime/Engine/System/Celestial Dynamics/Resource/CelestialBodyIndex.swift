/// World-owned lookup between persistent celestial identities and session-local entities.
///
/// Registration rejects duplicate identities in either direction. The stable
/// body order is always ascending `CelestialBodyID`, independent of entity or
/// component-store insertion order.
struct CelestialBodyIndex: PResource, Sendable {
    private(set) var orderedBodyIDs: [CelestialBodyID] = []

    private var bodyIDByEntityID: [EntityID: CelestialBodyID] = [:]
    private var entityIDByBodyID: [CelestialBodyID: EntityID] = [:]

    var count: Int {
        orderedBodyIDs.count
    }

    var isEmpty: Bool {
        orderedBodyIDs.isEmpty
    }

    init() {}

    subscript(bodyID: CelestialBodyID) -> EntityID? {
        entityIDByBodyID[bodyID]
    }

    /// Returns the persistent celestial identity registered for one live entity.
    func bodyID(for entityID: EntityID) -> CelestialBodyID? {
        bodyIDByEntityID[entityID]
    }

    /// Registers one bijective identity mapping without depending on insertion order.
    mutating func register(
        _ bodyID: CelestialBodyID,
        for entityID: EntityID
    ) throws(RegistrationError) {
        if let registeredEntityID = entityIDByBodyID[bodyID] {
            throw .bodyIDAlreadyRegistered(
                bodyID: bodyID,
                entityID: registeredEntityID
            )
        }
        if let registeredBodyID = bodyIDByEntityID[entityID] {
            throw .entityIDAlreadyRegistered(
                entityID: entityID,
                bodyID: registeredBodyID
            )
        }

        entityIDByBodyID[bodyID] = entityID
        bodyIDByEntityID[entityID] = bodyID
        orderedBodyIDs.append(bodyID)
        orderedBodyIDs.sort()
    }

    /// Typed construction failure that preserves the conflicting mapping.
    enum RegistrationError: Error, Equatable, Sendable {
        case bodyIDAlreadyRegistered(
            bodyID: CelestialBodyID,
            entityID: EntityID
        )
        case entityIDAlreadyRegistered(
            entityID: EntityID,
            bodyID: CelestialBodyID
        )

        var message: String {
            switch self {
            case let .bodyIDAlreadyRegistered(bodyID, entityID):
                "Celestial body ID \(bodyID) is already registered to entity \(entityID)."
            case let .entityIDAlreadyRegistered(entityID, bodyID):
                "Entity \(entityID) is already registered as celestial body \(bodyID)."
            }
        }
    }
}
