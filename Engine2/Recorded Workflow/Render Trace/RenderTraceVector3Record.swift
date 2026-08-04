import simd

/// Durable three-component scalar representation used by Render trace records.
nonisolated struct RenderTraceVector3Record: Codable, Equatable, Sendable {
    let x: Float
    let y: Float
    let z: Float

    /// Reconstructs the vector after persistence validation succeeds.
    var value: SIMD3<Float> {
        SIMD3<Float>(x, y, z)
    }

    /// Captures one finite domain vector for durable storage.
    init(_ value: SIMD3<Float>) throws(RenderTraceValidationError) {
        try self.init(x: value.x, y: value.y, z: value.z)
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            x: container.decode(Float.self, forKey: .x),
            y: container.decode(Float.self, forKey: .y),
            z: container.decode(Float.self, forKey: .z)
        )
    }

    private init(
        x: Float,
        y: Float,
        z: Float
    ) throws(RenderTraceValidationError) {
        let vector = SIMD3<Float>(x, y, z)
        guard vector.isFinite else {
            throw .nonfiniteVector
        }

        self.x = x
        self.y = y
        self.z = z
    }

    private enum CodingKeys: String, CodingKey {
        case x
        case y
        case z
    }
}
