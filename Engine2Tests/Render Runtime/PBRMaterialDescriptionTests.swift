import simd
import Testing
@testable import Engine2

struct PBRMaterialDescriptionTests {
    @Test func preservesAuthoredSceneLinearFactors() {
        let description = PBRMaterialDescription(
            baseColor: SIMD3<Float>(0.125, 0.5, 1),
            metallic: 0.75,
            perceptualRoughness: 0.25
        )

        // The contract preserves authored factors exactly. Roughness flooring
        // and any defensive shader clamping remain evaluation policy rather
        // than silently changing Game Content at this boundary.
        #expect(description.baseColor == SIMD3<Float>(0.125, 0.5, 1))
        #expect(description.metallic == 0.75)
        #expect(description.perceptualRoughness == 0.25)
    }

    @Test func legalEndpointsRemainDistinctValueDescriptions() {
        let dielectric = PBRMaterialDescription(
            baseColor: .zero,
            metallic: 0,
            perceptualRoughness: 0
        )
        let metal = PBRMaterialDescription(
            baseColor: SIMD3<Float>(repeating: 1),
            metallic: 1,
            perceptualRoughness: 1
        )
        let repeatedDielectric = PBRMaterialDescription(
            baseColor: .zero,
            metallic: 0,
            perceptualRoughness: 0
        )

        // Both closed-interval endpoints are legal authored inputs, and
        // synthesized equality provides catalog/test value semantics without
        // introducing a renderer-owned identity.
        #expect(dielectric == repeatedDielectric)
        #expect(dielectric != metal)
    }

    @Test func authoredRangePredicatesRejectEveryInvalidNumericClass() {
        let invalidScalars: [Float] = [
            -0.001,
            1.001,
            .nan,
            .infinity,
            -.infinity
        ]

        #expect(PBRMaterialDescription.acceptsUnitFactor(0))
        #expect(PBRMaterialDescription.acceptsUnitFactor(0.5))
        #expect(PBRMaterialDescription.acceptsUnitFactor(1))
        for invalid in invalidScalars {
            #expect(!PBRMaterialDescription.acceptsUnitFactor(invalid))
        }

        // Exercise each vector lane independently so deleting any one channel
        // check would weaken the authored base-color precondition observably.
        #expect(
            PBRMaterialDescription.acceptsBaseColor(
                SIMD3<Float>(0, 0.5, 1)
            )
        )
        for invalid in invalidScalars {
            #expect(
                !PBRMaterialDescription.acceptsBaseColor(
                    SIMD3<Float>(invalid, 0.5, 0.5)
                )
            )
            #expect(
                !PBRMaterialDescription.acceptsBaseColor(
                    SIMD3<Float>(0.5, invalid, 0.5)
                )
            )
            #expect(
                !PBRMaterialDescription.acceptsBaseColor(
                    SIMD3<Float>(0.5, 0.5, invalid)
                )
            )
        }
    }
}
