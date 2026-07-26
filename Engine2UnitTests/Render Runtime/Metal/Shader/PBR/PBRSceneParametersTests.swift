import simd
import Testing
@testable import Engine2

struct PBRSceneParametersTests {
    @Test func layoutMatchesTwoMetalFloat4LightLanes() {
        // Authored material factors moved to GPUInstance. These two scene-
        // constant lanes now carry only the fixed directional-light input.
        #expect(MemoryLayout<PBRSceneParameters>.alignment == 16)
        #expect(MemoryLayout<PBRSceneParameters>.size == 32)
        #expect(MemoryLayout<PBRSceneParameters>.stride == 32)
        #expect(
            MemoryLayout<PBRSceneParameters>.offset(
                of: \.directionToLightPadding
            ) == 0
        )
        #expect(
            MemoryLayout<PBRSceneParameters>.offset(
                of: \.lightColorIntensity
            ) == 16
        )
    }

    @Test func validationConstantsMatchTheProvenDirectionalLight() {
        // This light supplies incident radiance (8, 4, 2) at normal incidence.
        // Material factors are deliberately absent from the scene input.
        let expectedDirection = SIMD3<Float>(0, 0, 1)
        let expectedColor = SIMD3<Float>(1, 0.5, 0.25)
        #expect(
            PBRSceneParameters.validationDirectionToLightWorld
                == expectedDirection
        )
        #expect(
            PBRSceneParameters.validationLightColor
                == expectedColor
        )
        #expect(PBRSceneParameters.validationLightIntensity == 8)
    }

    @Test func identityCameraPacksLightWithoutChangingDirection() {
        let parameters = PBRSceneParameters(camera: .standard)
        let expectedDirection = SIMD4<Float>(0, 0, 1, 0)
        let expectedColorIntensity = SIMD4<Float>(1, 0.5, 0.25, 8)

        #expect(
            parameters.directionToLightPadding
                == expectedDirection
        )
        #expect(
            parameters.lightColorIntensity
                == expectedColorIntensity
        )
    }

    @Test func cameraTranslationDoesNotAffectTheViewSpaceLightDirection() {
        let firstPosition = SIMD3<Float>(0, 0, 8)
        let firstCamera = Camera(
            position: firstPosition,
            rotation: Transform.identityRotation,
            projection: .standardPerspective
        )
        let first = PBRSceneParameters(
            camera: firstCamera
        )
        let translatedPosition = SIMD3<Float>(37, -12, 4)
        let translatedCamera = Camera(
            position: translatedPosition,
            rotation: Transform.identityRotation,
            projection: .standardPerspective
        )
        let translated = PBRSceneParameters(
            camera: translatedCamera
        )

        // Direction vectors use w=0 semantics. The camera translation can move
        // view-space positions, but it must not make a directional light appear
        // to pivot or change length.
        #expect(
            first.directionToLightPadding
                == translated.directionToLightPadding
        )
    }

    @Test func inverseCameraRotationTransformsWorldLightIntoViewSpace() {
        let position = SIMD3<Float>(19, -7, 3)
        let rotationAxis = SIMD3<Float>(0, 1, 0)
        let rotation = simd_quatf(
            angle: .pi / 2,
            axis: rotationAxis
        )
        let camera = Camera(
            position: position,
            rotation: rotation,
            projection: .standardPerspective
        )
        let parameters = PBRSceneParameters(camera: camera)
        let direction = SIMD3<Float>(
            parameters.directionToLightPadding.x,
            parameters.directionToLightPadding.y,
            parameters.directionToLightPadding.z
        )

        // A +90-degree camera rotation about +Y applies its inverse to world
        // vectors, mapping the validation world's +Z surface-to-light direction
        // to view-space -X. Checking the sign catches a camera-to-world mix-up.
        let expectedDirection = SIMD3<Float>(-1, 0, 0)
        #expect(simd_distance(direction, expectedDirection) < 0.0001)
        #expect(abs(simd_length(direction) - 1) < 0.0001)
        #expect(parameters.directionToLightPadding.w == 0)
    }
}
