//
//  CameraTests.swift
//  Engine2Tests
//
//  Created by Codex on 6/13/26.
//

import simd
import Testing
@testable import Engine2

struct CameraTests {
    @Test func orthographicViewProjectionCentersCameraPosition() async throws {
        let camera = Camera(
            position: SIMD3<Float>(2, -1, 0),
            orthographicHeight: 4,
            nearPlane: -10,
            farPlane: 10
        )

        let matrix = camera.viewProjectionMatrix(aspectRatio: 2)
        let center = matrix * SIMD4<Float>(2, -1, 0, 1)
        let rightEdge = matrix * SIMD4<Float>(6, -1, 0, 1)
        let topEdge = matrix * SIMD4<Float>(2, 1, 0, 1)

        #expect(center.x.isApproximately(0))
        #expect(center.y.isApproximately(0))
        #expect(center.z.isApproximately(0.5))
        #expect(rightEdge.x.isApproximately(1))
        #expect(topEdge.y.isApproximately(1))
    }

    @Test func perspectiveProjectionCentersLookAtTarget() async throws {
        let camera = Camera.lookingAt(
            .zero,
            from: SIMD3<Float>(0, 0, 8),
            projection: .perspective(
                verticalFieldOfView: .pi / 2,
                near: 1,
                far: 20
            )
        )

        let matrix = camera.viewProjectionMatrix(aspectRatio: 1)
        let center = matrix * SIMD4<Float>(0, 0, 0, 1)
        let normalizedCenter = center / center.w

        #expect(center.w.isApproximately(8))
        #expect(normalizedCenter.x.isApproximately(0))
        #expect(normalizedCenter.y.isApproximately(0))
        #expect(normalizedCenter.z > 0)
        #expect(normalizedCenter.z < 1)
    }

    @Test func projectionUsesUnitAspectRatioForInvalidDrawableShapes() {
        let camera = Camera(
            projection: .perspective(
                verticalFieldOfView: .pi / 2,
                near: 0.1,
                far: 100
            )
        )
        let expected = camera.projectionMatrix(aspectRatio: 1)

        for invalidAspectRatio in [
            Float.zero,
            -2,
            .infinity,
            .nan
        ] {
            #expect(
                camera.projectionMatrix(
                    aspectRatio: invalidAspectRatio
                ).isApproximately(expected)
            )
        }
    }
}

private extension Float {
    func isApproximately(_ other: Float, tolerance: Float = 0.0001) -> Bool {
        abs(self - other) <= tolerance
    }
}

private extension simd_float4x4 {
    func isApproximately(
        _ other: simd_float4x4,
        tolerance: Float = 0.0001
    ) -> Bool {
        simd_length(columns.0 - other.columns.0) <= tolerance
            && simd_length(columns.1 - other.columns.1) <= tolerance
            && simd_length(columns.2 - other.columns.2) <= tolerance
            && simd_length(columns.3 - other.columns.3) <= tolerance
    }
}
