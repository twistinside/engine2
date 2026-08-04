import Foundation

/// Durable schema-v1 representation of one explicit Render viewpoint.
nonisolated struct RenderTraceViewpointRecord: Codable, Equatable, Sendable {
    let id: UUID
    let revision: UInt64
    let camera: RenderTraceCameraRecord

    /// Reconstructs the explicit viewpoint after persistence validation.
    var value: RenderViewpoint {
        RenderViewpoint(
            id: RenderViewpointID(rawValue: id),
            revision: RenderViewpointRevision(rawValue: revision),
            camera: camera.value
        )
    }

    /// Captures one validated explicit viewpoint for durable storage.
    init(_ viewpoint: RenderViewpoint) throws(RenderTraceValidationError) {
        self.id = viewpoint.id.rawValue
        self.revision = viewpoint.revision.rawValue
        self.camera = try RenderTraceCameraRecord(viewpoint.camera)
    }
}
