import simd

/// Durable quaternion representation with explicit `x`, `y`, `z`, `w` lanes.
nonisolated struct RenderTraceQuaternionRecord: Codable, Equatable, Sendable {
    let x: Float
    let y: Float
    let z: Float
    let w: Float

    /// Reconstructs the rotation after persistence validation succeeds.
    var value: simd_quatf {
        simd_quatf(vector: SIMD4<Float>(x, y, z, w))
    }

    /// Captures one finite, nonzero domain rotation for durable storage.
    init(_ value: simd_quatf) throws(RenderTraceValidationError) {
        let vector = value.vector
        try self.init(
            x: vector.x,
            y: vector.y,
            z: vector.z,
            w: vector.w
        )
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            x: container.decode(Float.self, forKey: .x),
            y: container.decode(Float.self, forKey: .y),
            z: container.decode(Float.self, forKey: .z),
            w: container.decode(Float.self, forKey: .w)
        )
    }

    private init(
        x: Float,
        y: Float,
        z: Float,
        w: Float
    ) throws(RenderTraceValidationError) {
        let vector = SIMD4<Float>(x, y, z, w)
        let lengthSquared = simd_length_squared(vector)
        guard vector.isFinite,
              lengthSquared.isFinite,
              lengthSquared > 0 else {
            throw .invalidQuaternion
        }

        self.x = x
        self.y = y
        self.z = z
        self.w = w
    }

    private enum CodingKeys: String, CodingKey {
        case x
        case y
        case z
        case w
    }
}
