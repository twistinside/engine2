import simd
import Testing
@testable import Engine2

struct GPUInstanceTests {
    @Test func layoutMatchesThreeAlignedMetalMatrices() {
        // MSL float4x4 is 64 bytes and float3x3 is three 16-byte columns.
        // Locking the aggregate stride protects address arithmetic in the
        // argument table when Swift or shader fields change independently.
        #expect(MemoryLayout<GPUInstance>.alignment == 16)
        #expect(MemoryLayout<GPUInstance>.stride == 176)
        #expect(
            MemoryLayout<GPUInstance>.offset(of: \.modelViewProjectionMatrix) == 0
        )
        #expect(MemoryLayout<GPUInstance>.offset(of: \.modelViewMatrix) == 64)
        #expect(MemoryLayout<GPUInstance>.offset(of: \.normalMatrix) == 128)
    }

    @Test func inverseTransposeKeepsNormalPerpendicularAfterNonuniformScale() {
        let localNormal = simd_normalize(SIMD3<Float>(1, 2, 3))
        let localTangent = simd_normalize(
            simd_cross(localNormal, SIMD3<Float>(0, 1, 0))
        )
        let secondLocalTangent = simd_normalize(
            simd_cross(localNormal, localTangent)
        )
        let transform = Transform(
            position: SIMD3<Float>(2, -1, -4),
            rotation: simd_quatf(
                angle: .pi / 3,
                axis: simd_normalize(SIMD3<Float>(1, 1, 0))
            ),
            scale: SIMD3<Float>(2, 0.5, 3)
        )
        let renderInstance = RenderInstance(meshID: .ball, transform: transform)
        let camera = Camera.lookingAt(.zero, from: SIMD3<Float>(0, 1, 8))
        let gpuInstance = GPUInstance(
            renderInstance,
            viewMatrix: camera.viewMatrix,
            projectionMatrix: camera.projectionMatrix(aspectRatio: 1)
        )
        let linearModelView = upperLeft3x3(of: gpuInstance.modelViewMatrix)
        let transformedNormal = simd_normalize(
            gpuInstance.normalMatrix * localNormal
        )
        let transformedTangent = linearModelView * localTangent
        let transformedSecondTangent = linearModelView * secondLocalTangent

        #expect(abs(simd_length(transformedNormal) - 1) < 0.0001)
        #expect(abs(simd_dot(transformedNormal, transformedTangent)) < 0.0001)
        #expect(
            abs(simd_dot(transformedNormal, transformedSecondTangent)) < 0.0001
        )
    }

    @Test func cameraTranslationDoesNotChangeNormalTransform() {
        let renderInstance = RenderInstance(
            meshID: .ball,
            transform: Transform(
                rotation: simd_quatf(
                    angle: .pi / 4,
                    axis: SIMD3<Float>(0, 1, 0)
                ),
                scale: SIMD3<Float>(2, 1, 0.5)
            )
        )
        let firstCamera = Camera(position: SIMD3<Float>(0, 0, 8))
        let translatedCamera = Camera(position: SIMD3<Float>(3, -2, 8))
        let projection = firstCamera.projectionMatrix(aspectRatio: 1)
        let first = GPUInstance(
            renderInstance,
            viewMatrix: firstCamera.viewMatrix,
            projectionMatrix: projection
        )
        let translated = GPUInstance(
            renderInstance,
            viewMatrix: translatedCamera.viewMatrix,
            projectionMatrix: projection
        )

        #expect(
            matricesAreApproximatelyEqual(
                first.normalMatrix,
                translated.normalMatrix
            )
        )
    }
}

private func upperLeft3x3(of matrix: simd_float4x4) -> simd_float3x3 {
    simd_float3x3(
        columns: (
            SIMD3<Float>(
                matrix.columns.0.x,
                matrix.columns.0.y,
                matrix.columns.0.z
            ),
            SIMD3<Float>(
                matrix.columns.1.x,
                matrix.columns.1.y,
                matrix.columns.1.z
            ),
            SIMD3<Float>(
                matrix.columns.2.x,
                matrix.columns.2.y,
                matrix.columns.2.z
            )
        )
    )
}

private func matricesAreApproximatelyEqual(
    _ lhs: simd_float3x3,
    _ rhs: simd_float3x3,
    tolerance: Float = 0.0001
) -> Bool {
    simd_length(lhs.columns.0 - rhs.columns.0) <= tolerance
        && simd_length(lhs.columns.1 - rhs.columns.1) <= tolerance
        && simd_length(lhs.columns.2 - rhs.columns.2) <= tolerance
}
