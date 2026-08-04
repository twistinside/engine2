import Foundation

/// Durable schema-v1 representation of a complete Simulation presentation.
nonisolated struct RenderTraceSnapshotRecord: Codable, Equatable, Sendable {
    let sessionID: UUID
    let tick: UInt64
    let camera: RenderTraceCameraRecord
    let entities: [RenderTraceEntityRecord]

    /// Reconstructs the complete presentation after persistence validation.
    var value: SimulationPresentationSnapshot {
        SimulationPresentationSnapshot(
            cursor: SimulationCursor(
                sessionID: SimulationSessionID(rawValue: sessionID),
                tick: SimulationTick(rawValue: tick)
            ),
            camera: camera.value,
            entityPresentations: entities.map(\.value)
        )
    }

    /// Captures one complete presentation after validating every recorded field.
    init(
        _ snapshot: SimulationPresentationSnapshot
    ) throws(RenderTraceValidationError) {
        var entities: [RenderTraceEntityRecord] = []
        entities.reserveCapacity(snapshot.entityPresentations.count)
        for presentation in snapshot.entityPresentations {
            entities.append(try RenderTraceEntityRecord(presentation))
        }
        try Self.validateUniqueEntityIdentities(in: entities)

        self.sessionID = snapshot.cursor.sessionID.rawValue
        self.tick = snapshot.cursor.tick.rawValue
        self.camera = try RenderTraceCameraRecord(snapshot.camera)
        self.entities = entities
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let entities = try container.decode(
            [RenderTraceEntityRecord].self,
            forKey: .entities
        )
        try Self.validateUniqueEntityIdentities(in: entities)

        self.sessionID = try container.decode(UUID.self, forKey: .sessionID)
        self.tick = try container.decode(UInt64.self, forKey: .tick)
        self.camera = try container.decode(
            RenderTraceCameraRecord.self,
            forKey: .camera
        )
        self.entities = entities
    }

    private static func validateUniqueEntityIdentities(
        in entities: [RenderTraceEntityRecord]
    ) throws(RenderTraceValidationError) {
        var identities: Set<EntityID> = []
        for entity in entities {
            guard identities.insert(entity.id.value).inserted else {
                throw .duplicateEntityIdentity(entity.id.value)
            }
        }
    }

    private enum CodingKeys: String, CodingKey {
        case sessionID
        case tick
        case camera
        case entities
    }
}
