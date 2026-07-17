import simd

/// Position, orientation, and scale used to place one renderable object in world space.
struct Transform {
    static let identityRotation = simd_quatf(angle: 0, axis: SIMD3<Float>(0, 0, 1))

    var position: SIMD3<Float>
    var rotation: simd_quatf
    var scale: SIMD3<Float>

    init(
        position: SIMD3<Float> = .zero,
        rotation: simd_quatf = Self.identityRotation,
        scale: SIMD3<Float> = SIMD3<Float>(repeating: 1)
    ) {
        self.position = position
        self.rotation = rotation
        self.scale = scale
    }

    /// Model matrix that transforms local mesh vertices into world space.
    var matrix: simd_float4x4 {
        .translation(position) * .rotation(rotation) * .scale(scale)
    }
}

extension Transform: Equatable {
    static func == (lhs: Transform, rhs: Transform) -> Bool {
        lhs.position == rhs.position &&
        lhs.rotation.vector == rhs.rotation.vector &&
        lhs.scale == rhs.scale
    }
}

extension simd_float4x4 {
    static var identity: simd_float4x4 {
        matrix_identity_float4x4
    }

    static func translation(_ translation: SIMD3<Float>) -> simd_float4x4 {
        simd_float4x4(
            columns: (
                SIMD4<Float>(1, 0, 0, 0),
                SIMD4<Float>(0, 1, 0, 0),
                SIMD4<Float>(0, 0, 1, 0),
                SIMD4<Float>(translation.x, translation.y, translation.z, 1)
            )
        )
    }

    static func rotation(_ rotation: simd_quatf) -> simd_float4x4 {
        let q = simd_normalize(rotation.vector)
        let x = q.x
        let y = q.y
        let z = q.z
        let w = q.w

        return simd_float4x4(
            columns: (
                SIMD4<Float>(
                    1 - 2 * y * y - 2 * z * z,
                    2 * x * y + 2 * w * z,
                    2 * x * z - 2 * w * y,
                    0
                ),
                SIMD4<Float>(
                    2 * x * y - 2 * w * z,
                    1 - 2 * x * x - 2 * z * z,
                    2 * y * z + 2 * w * x,
                    0
                ),
                SIMD4<Float>(
                    2 * x * z + 2 * w * y,
                    2 * y * z - 2 * w * x,
                    1 - 2 * x * x - 2 * y * y,
                    0
                ),
                SIMD4<Float>(0, 0, 0, 1)
            )
        )
    }

    static func scale(_ scale: SIMD3<Float>) -> simd_float4x4 {
        simd_float4x4(
            columns: (
                SIMD4<Float>(scale.x, 0, 0, 0),
                SIMD4<Float>(0, scale.y, 0, 0),
                SIMD4<Float>(0, 0, scale.z, 0),
                SIMD4<Float>(0, 0, 0, 1)
            )
        )
    }
}
