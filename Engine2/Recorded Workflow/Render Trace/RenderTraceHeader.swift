import Foundation

/// Version and compatibility identity shared by every frame in one Render trace.
///
/// `simulationCameraViewpointID` gives snapshot-camera frames one stable
/// Render-owned viewpoint identity while their Simulation cursors attribute
/// camera changes.
nonisolated struct RenderTraceHeader: Codable, Equatable, Sendable {
    let schemaVersion: RenderTraceSchemaVersion
    let traceID: UUID
    let contentIdentifier: RecordingContentIdentifier
    let simulationCameraViewpointID: RenderViewpointID

    init(
        schemaVersion: RenderTraceSchemaVersion,
        traceID: UUID,
        contentIdentifier: RecordingContentIdentifier,
        simulationCameraViewpointID: RenderViewpointID
    ) {
        self.schemaVersion = schemaVersion
        self.traceID = traceID
        self.contentIdentifier = contentIdentifier
        self.simulationCameraViewpointID = simulationCameraViewpointID
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawSchemaVersion = try container.decode(
            UInt32.self,
            forKey: .schemaVersion
        )
        guard let schemaVersion = RenderTraceSchemaVersion(
            rawValue: rawSchemaVersion
        ) else {
            throw RenderTraceValidationError.unsupportedSchemaVersion(
                rawSchemaVersion
            )
        }
        let traceID = try container.decode(UUID.self, forKey: .traceID)
        let contentIdentifier = try container.decode(
            RecordingContentIdentifier.self,
            forKey: .contentIdentifier
        )
        let simulationCameraViewpointID = RenderViewpointID(
            rawValue: try container.decode(
                UUID.self,
                forKey: .simulationCameraViewpointID
            )
        )

        self.init(
            schemaVersion: schemaVersion,
            traceID: traceID,
            contentIdentifier: contentIdentifier,
            simulationCameraViewpointID: simulationCameraViewpointID
        )
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion.rawValue, forKey: .schemaVersion)
        try container.encode(traceID, forKey: .traceID)
        try container.encode(contentIdentifier, forKey: .contentIdentifier)
        try container.encode(
            simulationCameraViewpointID.rawValue,
            forKey: .simulationCameraViewpointID
        )
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case traceID
        case contentIdentifier
        case simulationCameraViewpointID
    }
}
