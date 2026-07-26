import Testing
@testable import Engine2

struct SIMDTests {
    @Test func finiteAndNormalRequireEveryScalar() {
        #expect(SIMD4<Double>(1, -2, .leastNormalMagnitude, -Double.leastNormalMagnitude).isFinite)
        #expect(SIMD4<Double>(1, -2, .leastNormalMagnitude, -Double.leastNormalMagnitude).isNormal)
        #expect(SIMD2<Float>(1, .infinity).isFinite == false)
        #expect(SIMD2<Float>(1, 0).isNormal == false)
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
        #expect(SIMD2<Double>(0, -0.0).isZero)
        #expect(SIMD2<Double>(0, 1).isZero == false)
        #expect(SIMD3<Float>(1, .leastNonzeroMagnitude, 0).isSubnormal)
        #expect(SIMD3<Float>(1, .leastNormalMagnitude, 0).isSubnormal == false)
    }
}
