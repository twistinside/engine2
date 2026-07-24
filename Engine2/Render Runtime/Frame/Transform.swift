import simd

/// Position, orientation, and scale used to place one renderable object in world space.
nonisolated struct Transform: Sendable {
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

nonisolated extension Transform: Equatable {
    static func == (lhs: Transform, rhs: Transform) -> Bool {
        lhs.position == rhs.position &&
        lhs.rotation.vector == rhs.rotation.vector &&
        lhs.scale == rhs.scale
    }
}
