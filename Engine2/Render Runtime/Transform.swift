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

    /// Whether this transform can produce finite positions and a normal matrix.
    ///
    /// A zero scale collapses at least one surface dimension and makes the
    /// inverse-transpose normal transform undefined. Extremely small finite
    /// scale is also rejected when its reciprocal overflows. Snapshot
    /// projection uses this property to omit malformed or degenerate instances
    /// before they can introduce infinities or NaNs into a GPU frame.
    var supportsNormalTransform: Bool {
        let positionIsFinite = position.x.isFinite
            && position.y.isFinite
            && position.z.isFinite
        let rotationVector = rotation.vector
        let rotationLengthSquared = simd_length_squared(rotationVector)
        let rotationIsFiniteAndNonzero = rotationVector.x.isFinite
            && rotationVector.y.isFinite
            && rotationVector.z.isFinite
            && rotationVector.w.isFinite
            && rotationLengthSquared.isFinite
            && rotationLengthSquared > 0
        let scaleHasFiniteReciprocal = scale.x.isFinite
            && scale.y.isFinite
            && scale.z.isFinite
            && (1 / scale.x).isFinite
            && (1 / scale.y).isFinite
            && (1 / scale.z).isFinite

        return positionIsFinite
            && rotationIsFiniteAndNonzero
            && scaleHasFiniteReciprocal
            && matrix.hasFiniteElements
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
    /// Whether every scalar in this matrix is finite.
    ///
    /// Checking the constructed matrix catches arithmetic overflow that finite
    /// transform inputs alone cannot exclude.
    var hasFiniteElements: Bool {
        [columns.0, columns.1, columns.2, columns.3].allSatisfy { column in
            column.x.isFinite
                && column.y.isFinite
                && column.z.isFinite
                && column.w.isFinite
        }
    }

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
