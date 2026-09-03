import simd

/// Authoritative world-space orientation for one entity.
///
/// The quaternion is encoded through its SIMD vector so the component retains
/// stable `Codable` and exact `Equatable` value semantics independent of app
/// actor isolation.
struct RotationComponent: Component {
    /// Neutral orientation used when Game Content supplies no authored rotation.
    static let identity = Self(rotation: simd_quatf.identity)

    let rotation: simd_quatf
}

extension RotationComponent: Codable {
    /// Serialized representation used to reconstruct the quaternion exactly.
    private enum CodingKeys: String, CodingKey {
        case vector
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let vector = try container.decode(SIMD4<Float>.self, forKey: .vector)
        self.rotation = simd_quatf(vector: vector)
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(rotation.vector, forKey: .vector)
    }
}

extension RotationComponent: Equatable {
    static func == (lhs: RotationComponent, rhs: RotationComponent) -> Bool {
        lhs.rotation.vector == rhs.rotation.vector
    }
}
