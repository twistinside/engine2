import Testing
@testable import Engine2

struct SIMDTests {
    @Test func finiteAndNormalRequireEveryScalar() {
        let normal = SIMD4<Double>(
            1,
            -2,
            .leastNormalMagnitude,
            -Double.leastNormalMagnitude
        )
        let infinite = SIMD2<Float>(1, .infinity)
        let includesZero = SIMD2<Float>(1, 0)
        #expect(normal.isFinite)
        #expect(normal.isNormal)
        #expect(infinite.isFinite == false)
        #expect(includesZero.isNormal == false)
    }

    @Test func exceptionalClassificationsDetectAnyScalar() {
        let infinite = SIMD3<Float>(0, -.infinity, 1)
        let quietNaN = SIMD3<Float>(0, .nan, 1)
        let signalingNaN = SIMD3<Float>(0, .signalingNaN, 1)

        #expect(infinite.isInfinite)
        #expect(infinite.isNaN == false)
        #expect(quietNaN.isNaN)
        #expect(quietNaN.isSignalingNaN == false)
        #expect(signalingNaN.isNaN)
        #expect(signalingNaN.isSignalingNaN)
    }

    @Test func zeroRequiresEveryScalarAndSubnormalDetectsAnyScalar() {
        let zeros = SIMD2<Double>(0, -0.0)
        let nonzero = SIMD2<Double>(0, 1)
        let subnormal = SIMD3<Float>(1, .leastNonzeroMagnitude, 0)
        let normal = SIMD3<Float>(1, .leastNormalMagnitude, 0)
        #expect(zeros.isZero)
        #expect(nonzero.isZero == false)
        #expect(subnormal.isSubnormal)
        #expect(normal.isSubnormal == false)
    }
}
