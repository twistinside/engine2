//
//  TransformTests.swift
//  Engine2Tests
//
//  Created by Codex on 6/13/26.
//

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
}

private extension Float {
    func isApproximately(_ other: Float, tolerance: Float = 0.0001) -> Bool {
        abs(self - other) <= tolerance
    }
}
