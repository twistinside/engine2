import simd
import Testing

struct PBRProofParametersTests {
    @Test func layoutMatchesFourMetalFloat4Lanes() {
        #expect(MemoryLayout<PBRProofParameters>.alignment == 16)
        #expect(MemoryLayout<PBRProofParameters>.stride == 64)
        #expect(
            MemoryLayout<PBRProofParameters>.offset(
                of: \.baseColorMetallic
            ) == 0
        )
        #expect(
            MemoryLayout<PBRProofParameters>.offset(
                of: \.directionToLightRoughness
            ) == 16
        )
        #expect(
            MemoryLayout<PBRProofParameters>.offset(
                of: \.lightColorIntensity
            ) == 32
        )
        #expect(
            MemoryLayout<PBRProofParameters>.offset(
                of: \.directionToCameraPadding
            ) == 48
        )
    }

    @Test func initializerNormalizesDirectionsAndPreservesSemanticFactors() {
        let rotationAxis = SIMD3<Float>(0, 1, 0)
        let rotation = simd_quatf(
            angle: .pi / 2,
            axis: rotationAxis
        )
        let worldToView = simd_float3x3(rotation)
        let baseColor = SIMD3<Float>(0.2, 0.4, 0.8)
        let lightDirection = SIMD3<Float>(2, 0, 0)
        let lightColor = SIMD3<Float>(4, 2, 1)
        let cameraDirection = SIMD3<Float>(0, 0, 5)
        let parameters = PBRProofParameters(
            baseColor: baseColor,
            metallic: 0.75,
            perceptualRoughness: 0.3,
            directionToLightWorld: lightDirection,
            lightColor: lightColor,
            lightIntensity: 3,
            directionToCameraView: cameraDirection,
            worldToViewRotation: worldToView
        )

        let expectedBaseColorMetallic = SIMD4<Float>(0.2, 0.4, 0.8, 0.75)
        #expect(
            parameters.baseColorMetallic
                == expectedBaseColorMetallic
        )
        #expect(parameters.directionToLightRoughness.w == 0.3)
        let transformedLightDirection = SIMD3<Float>(
            parameters.directionToLightRoughness.x,
            parameters.directionToLightRoughness.y,
            parameters.directionToLightRoughness.z
        )
        #expect(
            abs(
                simd_length(transformedLightDirection) - 1
            ) < 0.0001
        )
        let expectedLightDirection = SIMD3<Float>(0, 0, -1)
        #expect(
            simd_distance(
                transformedLightDirection,
                expectedLightDirection
            ) < 0.0001
        )
        let expectedLightColorIntensity = SIMD4<Float>(4, 2, 1, 3)
        #expect(
            parameters.lightColorIntensity
                == expectedLightColorIntensity
        )
        let expectedCameraDirection = SIMD4<Float>(0, 0, 1, 0)
        #expect(
            parameters.directionToCameraPadding
                == expectedCameraDirection
        )
    }
}
