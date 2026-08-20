/// Persistent celestial identity and physical classification for one entity.
///
/// `CelestialBodyID` survives World reconstruction while the entity's
/// `EntityID` is local to one World. The World-owned ``CelestialBodyIndex``
/// resolves between those identity domains.
struct CCelestialIdentity: PComponent, Sendable {
    let bodyID: CelestialBodyID
    let kind: CelestialBodyKind

    init(bodyID: CelestialBodyID, kind: CelestialBodyKind) {
        precondition(
            bodyID != .primaryStar || kind == .star,
            "The primary-star celestial identity must classify its entity as a star."
        )
        self.bodyID = bodyID
        self.kind = kind
    }
}

extension CCelestialIdentity {
    private enum CodingKeys: String, CodingKey {
        case bodyID
        case kind
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let bodyID = try container.decode(CelestialBodyID.self, forKey: .bodyID)
        let kind = try container.decode(CelestialBodyKind.self, forKey: .kind)
        guard bodyID != .primaryStar || kind == .star else {
            throw DecodingError.dataCorruptedError(
                forKey: .kind,
                in: container,
                debugDescription: "The primary-star celestial identity must classify its entity as a star."
            )
        }
        self.init(bodyID: bodyID, kind: kind)
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(bodyID, forKey: .bodyID)
        try container.encode(kind, forKey: .kind)
    }
}
