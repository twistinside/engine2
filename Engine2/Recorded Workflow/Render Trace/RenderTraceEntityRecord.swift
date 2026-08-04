/// Durable schema-v1 presentation record for one entity.
nonisolated struct RenderTraceEntityRecord: Codable, Equatable, Sendable {
    let id: RenderTraceEntityIDRecord
    let position: RenderTraceVector3Record?
    let rotation: RenderTraceQuaternionRecord?
    let scale: RenderTraceVector3Record?
    let meshID: RenderTraceMeshIDRecord
    let materialID: RenderTraceMaterialIDRecord

    /// Reconstructs the entity presentation after persistence validation.
    var value: EntityPresentationSnapshot {
        EntityPresentationSnapshot(
            id: id.value,
            position: position?.value,
            rotation: rotation?.value,
            scale: scale?.value,
            meshID: meshID.value,
            materialID: materialID.value
        )
    }

    /// Captures every presentation field without exposing domain coding.
    init(
        _ presentation: EntityPresentationSnapshot
    ) throws(RenderTraceValidationError) {
        self.id = try RenderTraceEntityIDRecord(presentation.id)
        if let position = presentation.position {
            self.position = try RenderTraceVector3Record(position)
        } else {
            self.position = nil
        }
        if let rotation = presentation.rotation {
            self.rotation = try RenderTraceQuaternionRecord(rotation)
        } else {
            self.rotation = nil
        }
        if let scale = presentation.scale {
            self.scale = try RenderTraceVector3Record(scale)
        } else {
            self.scale = nil
        }
        self.meshID = RenderTraceMeshIDRecord(presentation.meshID)
        self.materialID = RenderTraceMaterialIDRecord(
            presentation.materialID
        )
    }
}
