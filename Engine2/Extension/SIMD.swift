/// Floating-point classification across every scalar lane of a SIMD value.
nonisolated extension SIMD where Scalar: FloatingPoint {
    /// Whether every scalar is finite.
    var isFinite: Bool {
        indices.allSatisfy { self[$0].isFinite }
    }

    /// Whether at least one scalar is positive or negative infinity.
    var isInfinite: Bool {
        indices.contains { self[$0].isInfinite }
    }

    /// Whether at least one scalar is NaN.
    var isNaN: Bool {
        indices.contains { self[$0].isNaN }
    }

    /// Whether at least one scalar is a signaling NaN.
    var isSignalingNaN: Bool {
        indices.contains { self[$0].isSignalingNaN }
    }

    /// Whether every scalar is normal.
    var isNormal: Bool {
        indices.allSatisfy { self[$0].isNormal }
    }

    /// Whether at least one scalar is subnormal.
    var isSubnormal: Bool {
        indices.contains { self[$0].isSubnormal }
    }

    /// Whether every scalar is positive or negative zero.
    var isZero: Bool {
        indices.allSatisfy { self[$0].isZero }
    }
}
