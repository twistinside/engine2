import simd
import Testing
@testable import Engine2

struct CameraTests {
    @Test func orthographicViewProjectionCentersCameraPosition() async throws {
        let position = SIMD3<Float>(2, -1, 0)
        let camera = Camera(
            position: position,
            rotation: Transform.identityRotation,
            projection: .orthographic(
                height: 4,
                near: 1,
                far: 21
            )
        )

        let matrix = camera.viewProjectionMatrix(aspectRatio: 2)
        // The sample points sit halfway between the positive near and far
        // distances, which is 11 units down the camera's local -Z axis.
        let center = matrix * SIMD4<Float>(2, -1, -11, 1)
        let rightEdge = matrix * SIMD4<Float>(6, -1, -11, 1)
        let topEdge = matrix * SIMD4<Float>(2, 1, -11, 1)

        #expect(center.x.isApproximately(0))
        #expect(center.y.isApproximately(0))
        #expect(center.z.isApproximately(0.5))
        #expect(rightEdge.x.isApproximately(1))
        #expect(topEdge.y.isApproximately(1))
    }

    @Test func orthographicProjectionMapsNearAndFarDistancesToMetalDepthRange() {
        let near: Float = 1
        let far: Float = 21
        let camera = Camera(
            position: .zero,
            rotation: Transform.identityRotation,
            projection: .orthographic(
                height: 4,
                near: near,
                far: far
            )
        )
        let projection = camera.projectionMatrix(aspectRatio: 1)
        let nearDepth = projectedDepth(ofViewZ: -near, through: projection)
        let middleDepth = projectedDepth(
            ofViewZ: -(near + far) / 2,
            through: projection
        )
        let farDepth = projectedDepth(ofViewZ: -far, through: projection)

        #expect(nearDepth.isApproximately(0))
        #expect(middleDepth.isApproximately(0.5))
        #expect(farDepth.isApproximately(1))
        #expect(nearDepth < middleDepth)
        #expect(middleDepth < farDepth)
    }

    @Test func perspectiveProjectionCentersLookAtTarget() async throws {
        let position = SIMD3<Float>(0, 0, 8)
        let up = SIMD3<Float>(0, 1, 0)
        let camera = Camera.lookingAt(
            .zero,
            from: position,
            up: up,
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

    @Test func perspectiveProjectionMapsNearAndFarDistancesToMetalDepthRange() {
        let near: Float = 1
        let far: Float = 21
        let camera = Camera(
            position: .zero,
            rotation: Transform.identityRotation,
            projection: .perspective(
                verticalFieldOfView: .pi / 2,
                near: near,
                far: far
            )
        )
        let projection = camera.projectionMatrix(aspectRatio: 1)
        let nearDepth = projectedDepth(ofViewZ: -near, through: projection)
        let middleDepth = projectedDepth(
            ofViewZ: -(near + far) / 2,
            through: projection
        )
        let farDepth = projectedDepth(ofViewZ: -far, through: projection)

        #expect(nearDepth.isApproximately(0))
        #expect(farDepth.isApproximately(1))
        // Perspective depth is intentionally nonlinear, so its interior sample
        // need only remain strictly ordered between the two exact endpoints.
        #expect(nearDepth < middleDepth)
        #expect(middleDepth < farDepth)
    }

    @Test func projectionUsesUnitAspectRatioForInvalidDrawableShapes() {
        let position = SIMD3<Float>(0, 0, 8)
        let camera = Camera(
            position: position,
            rotation: Transform.identityRotation,
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

    @Test func viewTransformSupportRejectsInvalidCameraState() {
        #expect(Camera.standard.supportsViewTransform)
        let nonfinitePosition = SIMD3<Float>(.nan, 0, 8)
        let nonfiniteCamera = Camera(
            position: nonfinitePosition,
            rotation: Transform.identityRotation,
            projection: .standardPerspective
        )
        let standardPosition = SIMD3<Float>(0, 0, 8)
        let invalidRotation = simd_quatf(vector: .zero)
        let invalidOrientationCamera = Camera(
            position: standardPosition,
            rotation: invalidRotation,
            projection: .standardPerspective
        )
        let extremePosition = SIMD3<Float>(
            .greatestFiniteMagnitude,
            0,
            -.greatestFiniteMagnitude
        )
        let rotationAxis = SIMD3<Float>(0, 1, 0)
        let rotation = simd_quatf(angle: .pi / 4, axis: rotationAxis)
        let overflowingCamera = Camera(
            position: extremePosition,
            rotation: rotation,
            projection: .standardPerspective
        )
        #expect(nonfiniteCamera.supportsViewTransform == false)
        #expect(invalidOrientationCamera.supportsViewTransform == false)
        #expect(overflowingCamera.supportsViewTransform == false)
    }

    @Test func standardCameraNamesTheCompleteNeutralView() {
        let position = SIMD3<Float>(0, 0, 8)
        let expected = Camera(
            position: position,
            rotation: Transform.identityRotation,
            projection: .perspective(
                verticalFieldOfView: .pi / 3,
                near: 0.1,
                far: 100
            )
        )
        #expect(Camera.standard == expected)
    }
}

/// Applies homogeneous division so projection tests assert the depth value
/// consumed by Metal rather than an intermediate clip-space coordinate.
private func projectedDepth(ofViewZ viewZ: Float, through projection: simd_float4x4) -> Float {
    let clipPosition = projection * SIMD4<Float>(0, 0, viewZ, 1)
    return clipPosition.z / clipPosition.w
}

private extension Float {
    func isApproximately(_ other: Float, tolerance: Float = 0.0001) -> Bool {
        abs(self - other) <= tolerance
    }
}

private extension simd_float4x4 {
    func isApproximately(_ other: simd_float4x4, tolerance: Float = 0.0001) -> Bool {
        simd_length(columns.0 - other.columns.0) <= tolerance
            && simd_length(columns.1 - other.columns.1) <= tolerance
            && simd_length(columns.2 - other.columns.2) <= tolerance
            && simd_length(columns.3 - other.columns.3) <= tolerance
    }
}
