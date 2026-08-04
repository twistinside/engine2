/// Durable, validated representation of one complete Render camera.
nonisolated struct RenderTraceCameraRecord: Codable, Equatable, Sendable {
    let position: RenderTraceVector3Record
    let rotation: RenderTraceQuaternionRecord
    let projection: RenderTraceCameraProjectionRecord

    /// Reconstructs the camera after persistence validation succeeds.
    var value: Camera {
        Camera(
            position: position.value,
            rotation: rotation.value,
            projection: projection.value
        )
    }

    /// Captures one camera that can form a finite view transform.
    init(_ camera: Camera) throws(RenderTraceValidationError) {
        guard camera.supportsViewTransform else {
            throw .invalidCameraTransform
        }

        self.position = try RenderTraceVector3Record(camera.position)
        self.rotation = try RenderTraceQuaternionRecord(camera.rotation)
        self.projection = try RenderTraceCameraProjectionRecord(
            camera.projection
        )
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let position = try container.decode(
            RenderTraceVector3Record.self,
            forKey: .position
        )
        let rotation = try container.decode(
            RenderTraceQuaternionRecord.self,
            forKey: .rotation
        )
        let projection = try container.decode(
            RenderTraceCameraProjectionRecord.self,
            forKey: .projection
        )
        let camera = Camera(
            position: position.value,
            rotation: rotation.value,
            projection: projection.value
        )
        guard camera.supportsViewTransform else {
            throw RenderTraceValidationError.invalidCameraTransform
        }

        self.position = position
        self.rotation = rotation
        self.projection = projection
    }

    private enum CodingKeys: String, CodingKey {
        case position
        case rotation
        case projection
    }
}
