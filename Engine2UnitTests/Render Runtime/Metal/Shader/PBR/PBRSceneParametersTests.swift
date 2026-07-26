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
        #expect(
            PBRSceneParameters.validationDirectionToLightWorld
                == SIMD3<Float>(0, 0, 1)
        )
        #expect(
            PBRSceneParameters.validationLightColor
                == SIMD3<Float>(1, 0.5, 0.25)
        )
        #expect(PBRSceneParameters.validationLightIntensity == 8)
    }

    @Test func identityCameraPacksLightWithoutChangingDirection() {
        let parameters = PBRSceneParameters(camera: .standard)

        #expect(
            parameters.directionToLightPadding
                == SIMD4<Float>(0, 0, 1, 0)
        )
        #expect(
            parameters.lightColorIntensity
                == SIMD4<Float>(1, 0.5, 0.25, 8)
        )
    }

    @Test func cameraTranslationDoesNotAffectTheViewSpaceLightDirection() {
        let firstCamera = Camera(
            position: SIMD3<Float>(0, 0, 8),
            rotation: Transform.identityRotation,
            projection: .standardPerspective
        )
        let first = PBRSceneParameters(
            camera: firstCamera
        )
        let translatedCamera = Camera(
            position: SIMD3<Float>(37, -12, 4),
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
        let rotation = simd_quatf(
            angle: .pi / 2,
            axis: SIMD3<Float>(0, 1, 0)
        )
        let camera = Camera(
            position: SIMD3<Float>(19, -7, 3),
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
        #expect(simd_distance(direction, SIMD3<Float>(-1, 0, 0)) < 0.0001)
        #expect(abs(simd_length(direction) - 1) < 0.0001)
        #expect(parameters.directionToLightPadding.w == 0)
    }
}
