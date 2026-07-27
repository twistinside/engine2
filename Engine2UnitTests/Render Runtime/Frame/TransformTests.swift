import simd
import Testing
@testable import Engine2

struct TransformTests {
    @Test func matrixAppliesScaleRotationThenTranslation() async throws {
        let transform = Transform(
            position: SIMD3<Float>(2, 3, 4),
            rotation: simd_quatf(angle: .pi / 2, axis: SIMD3<Float>(0, 0, 1)),
            scale: SIMD3<Float>(2, 1, 1)
        )

        let transformed = transform.matrix * SIMD4<Float>(1, 0, 0, 1)

        #expect(transformed.x.isApproximately(2))
        #expect(transformed.y.isApproximately(5))
        #expect(transformed.z.isApproximately(4))
        #expect(transformed.w.isApproximately(1))
    }

    @Test func normalTransformSupportRejectsDegenerateOrNonfiniteInputs() {
        #expect(Transform.identity.supportsNormalTransform)
        let degenerate = Transform(
            position: .zero,
            rotation: .identity,
            scale: SIMD3<Float>(1, 0, 1)
        )
        let subnormal = Transform(
            position: .zero,
            rotation: .identity,
            scale: SIMD3<Float>(Float.leastNonzeroMagnitude, 1, 1)
        )
        let nonfinite = Transform(
            position: SIMD3<Float>(.infinity, 0, 0),
            rotation: .identity,
            scale: SIMD3<Float>(repeating: 1)
        )
        let invalidOrientation = Transform(
            position: .zero,
            rotation: simd_quatf(vector: .zero),
            scale: SIMD3<Float>(repeating: 1)
        )
        #expect(degenerate.supportsNormalTransform == false)
        #expect(subnormal.supportsNormalTransform == false)
        #expect(nonfinite.supportsNormalTransform == false)
        #expect(invalidOrientation.supportsNormalTransform == false)
    }

    @Test func identityTransformLeavesLocalPositionsUnchanged() {
        #expect(Transform.identity.matrix == matrix_identity_float4x4)
    }
}

private extension Float {
    func isApproximately(_ other: Float, tolerance: Float = 0.0001) -> Bool {
        abs(self - other) <= tolerance
    }
}
