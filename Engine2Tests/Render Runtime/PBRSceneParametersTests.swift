import simd
import Testing
@testable import Engine2

@MainActor
struct PBRSceneParametersTests {
    @Test func layoutMatchesThreeMetalFloat4Lanes() {
        // The temporary M3 binding is deliberately three inspectable float4
        // lanes. Exact offsets protect both Swift/Metal agreement and argument-
        // buffer address arithmetic without freezing Milestone 4's material ABI.
        #expect(MemoryLayout<PBRSceneParameters>.alignment == 16)
        #expect(MemoryLayout<PBRSceneParameters>.size == 48)
        #expect(MemoryLayout<PBRSceneParameters>.stride == 48)
        #expect(
            MemoryLayout<PBRSceneParameters>.offset(
                of: \.baseColorMetallic
            ) == 0
        )
        #expect(
            MemoryLayout<PBRSceneParameters>.offset(
                of: \.directionToLightRoughness
            ) == 16
        )
        #expect(
            MemoryLayout<PBRSceneParameters>.offset(
                of: \.lightColorIntensity
            ) == 32
        )
    }

    @Test func validationConstantsMatchTheProvenHDRReferenceScene() {
        // These values reproduce the M2 HDR reference at normal incidence:
        // incident radiance is (8, 4, 2), with a colored dielectric material.
        // Keeping the constants explicit makes a visible change intentional and
        // prevents tests from deriving their oracle from the packed value itself.
        #expect(
            PBRSceneParameters.validationBaseColor
                == SIMD3<Float>(0.5, 0.25, 0.125)
        )
        #expect(PBRSceneParameters.validationMetallic == 0)
        #expect(PBRSceneParameters.validationPerceptualRoughness == 0.5)
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

    @Test func identityCameraPacksValidationMaterialAndLightWithoutChangingDirection() {
        let parameters = PBRSceneParameters(camera: Camera())

        #expect(
            parameters.baseColorMetallic
                == SIMD4<Float>(0.5, 0.25, 0.125, 0)
        )
        #expect(
            parameters.directionToLightRoughness
                == SIMD4<Float>(0, 0, 1, 0.5)
        )
        #expect(
            parameters.lightColorIntensity
                == SIMD4<Float>(1, 0.5, 0.25, 8)
        )
    }

    @Test func cameraTranslationDoesNotAffectTheViewSpaceLightDirection() {
        let first = PBRSceneParameters(
            camera: Camera(position: SIMD3<Float>(0, 0, 8))
        )
        let translated = PBRSceneParameters(
            camera: Camera(position: SIMD3<Float>(37, -12, 4))
        )

        // Direction vectors use w=0 semantics. The camera translation can move
        // view-space positions, but it must not make a directional light appear
        // to pivot or change length.
        #expect(
            first.directionToLightRoughness
                == translated.directionToLightRoughness
        )
    }

    @Test func inverseCameraRotationTransformsWorldLightIntoViewSpace() {
        let camera = Camera(
            position: SIMD3<Float>(19, -7, 3),
            rotation: simd_quatf(
                angle: .pi / 2,
                axis: SIMD3<Float>(0, 1, 0)
            )
        )
        let parameters = PBRSceneParameters(camera: camera)
        let direction = SIMD3<Float>(
            parameters.directionToLightRoughness.x,
            parameters.directionToLightRoughness.y,
            parameters.directionToLightRoughness.z
        )

        // A +90-degree camera rotation about +Y applies its inverse to world
        // vectors, mapping the validation world's +Z surface-to-light direction
        // to view-space -X. Checking the sign catches a camera-to-world mix-up.
        #expect(simd_distance(direction, SIMD3<Float>(-1, 0, 0)) < 0.0001)
        #expect(abs(simd_length(direction) - 1) < 0.0001)
        #expect(parameters.directionToLightRoughness.w == 0.5)
    }
}
