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
        let worldToView = simd_float3x3(
            simd_quatf(
                angle: .pi / 2,
                axis: SIMD3<Float>(0, 1, 0)
            )
        )
        let parameters = PBRProofParameters(
            baseColor: SIMD3<Float>(0.2, 0.4, 0.8),
            metallic: 0.75,
            perceptualRoughness: 0.3,
            directionToLightWorld: SIMD3<Float>(2, 0, 0),
            lightColor: SIMD3<Float>(4, 2, 1),
            lightIntensity: 3,
            directionToCameraView: SIMD3<Float>(0, 0, 5),
            worldToViewRotation: worldToView
        )

        #expect(
            parameters.baseColorMetallic
                == SIMD4<Float>(0.2, 0.4, 0.8, 0.75)
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
        #expect(
            simd_distance(
                transformedLightDirection,
                SIMD3<Float>(0, 0, -1)
            ) < 0.0001
        )
        #expect(
            parameters.lightColorIntensity
                == SIMD4<Float>(4, 2, 1, 3)
        )
        #expect(
            parameters.directionToCameraPadding
                == SIMD4<Float>(0, 0, 1, 0)
        )
    }
}
