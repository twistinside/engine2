import simd
import Testing
@testable import Engine2

struct GPUInstanceTests {
    @Test func layoutMatchesMetalTransformsAndTwoMaterialLanes() {
        // MSL float4x4 is 64 bytes, float3x3 is three 16-byte columns, and the
        // material uses two explicit float4 lanes. Locking every offset protects
        // per-draw address arithmetic and the independent Swift/Metal layouts.
        #expect(MemoryLayout<GPUInstance>.alignment == 16)
        #expect(MemoryLayout<GPUInstance>.stride == 208)
        #expect(
            MemoryLayout<GPUInstance>.offset(of: \.modelViewProjectionMatrix) == 0
        )
        #expect(MemoryLayout<GPUInstance>.offset(of: \.modelViewMatrix) == 64)
        #expect(MemoryLayout<GPUInstance>.offset(of: \.normalMatrix) == 128)
        #expect(MemoryLayout<GPUInstance>.offset(of: \.baseColorMetallic) == 176)
        #expect(
            MemoryLayout<GPUInstance>.offset(
                of: \.perceptualRoughnessPadding
            ) == 192
        )
    }

    @Test func packsAuthoredFactorsIntoAlignedPerDrawLanes() throws {
        let baseColor = SIMD3<Float>(0.2, 0.4, 0.8)
        let material = PBRMaterialDescription(
            baseColor: baseColor,
            metallic: 0.75,
            perceptualRoughness: 0.3
        )
        let renderInstance = try projectedInstance(
            transform: .identity,
            viewMatrix: matrix_identity_float4x4
        )
        let gpuInstance = GPUInstance(
            renderInstance,
            material: material,
            projectionMatrix: matrix_identity_float4x4
        )

        #expect(gpuInstance.modelViewMatrix == renderInstance.modelViewMatrix)
        #expect(gpuInstance.normalMatrix == renderInstance.normalMatrix)
        let expectedBaseColorMetallic = SIMD4<Float>(0.2, 0.4, 0.8, 0.75)
        let expectedRoughnessPadding = SIMD4<Float>(0.3, 0, 0, 0)
        #expect(
            gpuInstance.baseColorMetallic
                == expectedBaseColorMetallic
        )
        #expect(
            gpuInstance.perceptualRoughnessPadding
                == expectedRoughnessPadding
        )
    }

    @Test func inverseTransposeKeepsNormalPerpendicularAfterNonuniformScale() throws {
        let localNormalDirection = SIMD3<Float>(1, 2, 3)
        let localNormal = simd_normalize(localNormalDirection)
        let tangentReference = SIMD3<Float>(0, 1, 0)
        let localTangent = simd_normalize(
            simd_cross(localNormal, tangentReference)
        )
        let secondLocalTangent = simd_normalize(
            simd_cross(localNormal, localTangent)
        )
        let position = SIMD3<Float>(2, -1, -4)
        let rotationDirection = SIMD3<Float>(1, 1, 0)
        let rotationAxis = simd_normalize(rotationDirection)
        let rotation = simd_quatf(
            angle: .pi / 3,
            axis: rotationAxis
        )
        let scale = SIMD3<Float>(2, 0.5, 3)
        let transform = Transform(
            position: position,
            rotation: rotation,
            scale: scale
        )
        let cameraPosition = SIMD3<Float>(0, 1, 8)
        let cameraUp = SIMD3<Float>(0, 1, 0)
        let camera = Camera.lookingAt(
            .zero,
            from: cameraPosition,
            up: cameraUp,
            projection: .standardPerspective
        )
        let renderInstance = try projectedInstance(
            transform: transform,
            viewMatrix: camera.viewMatrix
        )
        let gpuInstance = GPUInstance(
            renderInstance,
            material: Self.warmDielectric,
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

    @Test func cameraTranslationDoesNotChangeNormalTransform() throws {
        let rotationAxis = SIMD3<Float>(0, 1, 0)
        let rotation = simd_quatf(
            angle: .pi / 4,
            axis: rotationAxis
        )
        let scale = SIMD3<Float>(2, 1, 0.5)
        let transform = Transform(
            position: .zero,
            rotation: rotation,
            scale: scale
        )
        let firstCameraPosition = SIMD3<Float>(0, 0, 8)
        let firstCamera = Camera(
            position: firstCameraPosition,
            rotation: Transform.identityRotation,
            projection: .standardPerspective
        )
        let translatedCameraPosition = SIMD3<Float>(3, -2, 8)
        let translatedCamera = Camera(
            position: translatedCameraPosition,
            rotation: Transform.identityRotation,
            projection: .standardPerspective
        )
        let projection = firstCamera.projectionMatrix(aspectRatio: 1)
        let firstRenderInstance = try projectedInstance(
            transform: transform,
            viewMatrix: firstCamera.viewMatrix
        )
        let translatedRenderInstance = try projectedInstance(
            transform: transform,
            viewMatrix: translatedCamera.viewMatrix
        )
        let first = GPUInstance(
            firstRenderInstance,
            material: Self.warmDielectric,
            projectionMatrix: projection
        )
        let translated = GPUInstance(
            translatedRenderInstance,
            material: Self.warmDielectric,
            projectionMatrix: projection
        )

        #expect(
            matricesAreApproximatelyEqual(
                first.normalMatrix,
                translated.normalMatrix
            )
        )
    }

    private func projectedInstance(transform: Transform, viewMatrix: simd_float4x4) throws -> RenderInstance {
        let entityID = EntityID(index: 0, generation: 0)
        let presentation = EntityPresentationSnapshot(
            id: entityID,
            position: transform.position,
            rotation: transform.rotation,
            scale: transform.scale,
            meshID: .ball,
            materialID: .warmDielectric
        )
        return try RenderInstance(
            projecting: presentation,
            viewMatrix: viewMatrix
        )
    }

    private static let warmDielectricBaseColor = SIMD3<Float>(0.5, 0.25, 0.125)

    private static let warmDielectric = PBRMaterialDescription(
        baseColor: warmDielectricBaseColor,
        metallic: 0,
        perceptualRoughness: 0.5
    )
}

private func upperLeft3x3(of matrix: simd_float4x4) -> simd_float3x3 {
    let firstColumn = SIMD3<Float>(
        matrix.columns.0.x,
        matrix.columns.0.y,
        matrix.columns.0.z
    )
    let secondColumn = SIMD3<Float>(
        matrix.columns.1.x,
        matrix.columns.1.y,
        matrix.columns.1.z
    )
    let thirdColumn = SIMD3<Float>(
        matrix.columns.2.x,
        matrix.columns.2.y,
        matrix.columns.2.z
    )
    let columns = (firstColumn, secondColumn, thirdColumn)
    return simd_float3x3(columns: columns)
}

private func matricesAreApproximatelyEqual(_ lhs: simd_float3x3, _ rhs: simd_float3x3, tolerance: Float = 0.0001) -> Bool {
    simd_length(lhs.columns.0 - rhs.columns.0) <= tolerance
        && simd_length(lhs.columns.1 - rhs.columns.1) <= tolerance
        && simd_length(lhs.columns.2 - rhs.columns.2) <= tolerance
}
