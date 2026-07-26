import Foundation
import simd
import Testing
@testable import Engine2

struct MetalHDRPipelineTests {
    @Test func validationPBRSurvivesHDRAndPresentsWithOneSRGBTransfer() throws {
        let renderer = try MetalHDRPipelineTestRenderer()
        let result = try renderer.render(outputMode: .surface)

        // Independent normal-incidence reference for Game Content's authored
        // warm dielectric and incident radiance (8, 4, 2). Reproducing M3's
        // exact output proves the transitional renderer material was removed
        // without changing the established HDR pathway.
        let expectedSceneLinearRGBA = SIMD4<Float>(
            1.62974664,
            0.5092958,
            0.17825354,
            1
        )
        expectStoredHalfRGBA(
            result.sceneLinearRGBA,
            approximately: expectedSceneLinearRGBA
        )
        #expect(result.sceneLinearRGBA.x > 1)

        // Presentation reads the already quantized half-float scene value,
        // multiplies by validation exposure 1, and applies Reinhard per channel.
        // The `_srgb` attachment then performs the sole transfer encoding; CPU
        // `getBytes` exposes those encoded BGRA bytes without a shader read.
        let sceneRGB = result.sceneLinearRGBA.xyz
        let one = SIMD3<Float>(repeating: 1)
        let reinhard = sceneRGB / (one + sceneRGB)
        let expectedOnceEncoded = srgbEncodedBGRA8(from: reinhard)
        expectBGRA8(
            result.presentedBGRA8,
            approximately: expectedOnceEncoded
        )

        // These alternatives make the transfer assertion diagnostic. A linear
        // UNorm store would match `notEncoded`; manually encoding in the shader
        // and then writing an `_srgb` target would match `twiceEncoded`.
        let notEncoded = linearBGRA8(from: reinhard)
        let twiceEncoded = srgbEncodedBGRA8(
            from: reinhard.applyingSRGBTransfer
        )
        #expect(byteDistance(result.presentedBGRA8, notEncoded) > 40)
        #expect(byteDistance(result.presentedBGRA8, twiceEncoded) > 40)
    }

    @Test func authoredGoldFactorsReachTheVisiblePBRPath() throws {
        let renderer = try MetalHDRPipelineTestRenderer()
        let result = try renderer.render(
            outputMode: .surface,
            materialID: .goldMetal
        )

        // Independent normal-incidence metallic-GGX reference for Game
        // Content's base color (1, 0.766, 0.336), roughness 0.35, and the fixed
        // incident radiance (8, 4, 2). This differs strongly from the warm
        // dielectric and proves the authored factors reach the production
        // surface fragment rather than a retained renderer fallback.
        let expectedSceneLinearRGBA = SIMD4<Float>(
            42.42364164,
            16.24825475,
            3.5635859,
            1
        )
        expectStoredHalfRGBA(
            result.sceneLinearRGBA,
            approximately: expectedSceneLinearRGBA
        )
    }

    @Test func oneGeometryBufferKeepsDistinctPerDrawAuthoredMaterials() throws {
        let renderer = try MetalHDRPipelineTestRenderer()
        let forward = try renderer.renderAuthoredMaterialPair([
            .warmDielectric,
            .goldMetal
        ])
        let reversed = try renderer.renderAuthoredMaterialPair([
            .goldMetal,
            .warmDielectric
        ])

        // Both draws use the same triangle address, pipeline, scene light, and
        // command buffer. Their samples are symmetric around the view center,
        // so reversing only the identities must reverse the exact stored
        // results. This proves both draws retained the correct material order,
        // rather than merely producing two arbitrary distinct records.
        #expect(forward.left == reversed.right)
        #expect(forward.right == reversed.left)
        #expect(forward.left != forward.right)
        #expect(forward.left.w == 1)
        #expect(forward.right.w == 1)
    }

    @Test func publishedSceneMaterialFactorsReachProductionBindings() throws {
        let scene = PublishedMaterialValidationScene()
        let materialIDs = scene.materialIDs
        let descriptions = try scene.materialDescriptions()
        let renderer = try MetalHDRPipelineTestRenderer()

        #expect(materialIDs.count == 6)
        #expect(descriptions.count == materialIDs.count)

        let baseColors = try renderer.renderDiagnostic(
            .baseColor,
            materialIDs: materialIDs
        )
        let metallicValues = try renderer.renderDiagnostic(
            .metallic,
            materialIDs: materialIDs
        )
        let roughnessValues = try renderer.renderDiagnostic(
            .roughness,
            materialIDs: materialIDs
        )

        // The identities originate in BasicWorldBuilder and cross capture plus
        // RenderFrame projection before catalog resolution. Exact factor views
        // therefore catch order, address, packing, and fragment-lane mistakes.
        for index in materialIDs.indices {
            let description = descriptions[index]
            let expectedBaseColor = SIMD4<Float>(
                description.baseColor,
                1
            )
            expectStoredHalfRGBA(
                baseColors[index],
                approximately: expectedBaseColor
            )
            let expectedMetallic = SIMD4<Float>(
                repeating: description.metallic
            ).replacingW(with: 1)
            expectStoredHalfRGBA(
                metallicValues[index],
                approximately: expectedMetallic
            )
            let effectiveRoughness = max(
                description.perceptualRoughness,
                0.089
            )
            let expectedRoughness = SIMD4<Float>(
                repeating: effectiveRoughness
            ).replacingW(with: 1)
            expectStoredHalfRGBA(
                roughnessValues[index],
                approximately: expectedRoughness
            )
        }
    }

    @Test func publishedSceneSeparatesDiffuseAndSpecularContributions() throws {
        let scene = PublishedMaterialValidationScene()
        let materialIDs = scene.materialIDs
        let descriptions = try scene.materialDescriptions()
        let renderer = try MetalHDRPipelineTestRenderer()

        let shaded = try renderer.renderAuthoredMaterialScene(materialIDs)
            .map(\.sceneLinearRGBA)
        let diffuse = try renderer.renderDiagnostic(
            .diffuse,
            materialIDs: materialIDs
        )
        let specular = try renderer.renderDiagnostic(
            .specular,
            materialIDs: materialIDs
        )

        #expect(shaded.count == 6)
        for index in materialIDs.indices {
            let diffuseRGB = diffuse[index].xyz
            let specularRGB = specular[index].xyz

            if descriptions[index].metallic == 1 {
                let expectedDiffuse = SIMD4<Float>(0, 0, 0, 1)
                expectStoredHalfRGBA(
                    diffuse[index],
                    approximately: expectedDiffuse
                )
            } else {
                #expect(diffuseRGB.x > 0)
                #expect(diffuseRGB.y > 0)
                #expect(diffuseRGB.z > 0)
            }

            #expect(specularRGB.x.isFinite && specularRGB.x > 0)
            #expect(specularRGB.y.isFinite && specularRGB.y > 0)
            #expect(specularRGB.z.isFinite && specularRGB.z > 0)
            expectStoredHalfRGBSum(
                shaded[index],
                diffuse[index],
                specular[index]
            )
        }
    }

    @Test func everyPublishedSceneMaterialSurvivesHDRAndPresentation() throws {
        let materialIDs = PublishedMaterialValidationScene().materialIDs
        let renderer = try MetalHDRPipelineTestRenderer()
        let results = try renderer.renderAuthoredMaterialScene(materialIDs)

        #expect(results.count == 6)
        #expect(
            results.contains { result in
                result.sceneLinearRGBA.x > 1
                    || result.sceneLinearRGBA.y > 1
                    || result.sceneLinearRGBA.z > 1
            }
        )

        for result in results {
            let sceneRGB = result.sceneLinearRGBA.xyz
            #expect(sceneRGB.x.isFinite && sceneRGB.x >= 0)
            #expect(sceneRGB.y.isFinite && sceneRGB.y >= 0)
            #expect(sceneRGB.z.isFinite && sceneRGB.z >= 0)
            #expect(result.sceneLinearRGBA.w == 1)

            // Derive final bytes from this draw's already-quantized HDR sample,
            // proving each stored material result uses the expected presentation
            // mapping rather than a separate factor or transfer assumption.
            let one = SIMD3<Float>(repeating: 1)
            let reinhard = sceneRGB
                / (one + sceneRGB)
            expectBGRA8(
                result.presentedBGRA8,
                approximately: srgbEncodedBGRA8(from: reinhard)
            )
        }
    }

    @Test func normalDiagnosticBypassesExposureAndReinhard() throws {
        let renderer = try MetalHDRPipelineTestRenderer()
        let normal = SIMD3<Float>(1, 0, 0)
        let exposure = ManualExposure(multiplier: 8)
        let result = try renderer.render(
            outputMode: .viewSpaceNormals,
            normal: normal,
            // A deliberately large exposure makes accidental use of the
            // surface presentation pipeline unmistakable.
            exposure: exposure
        )

        let expectedLinear = SIMD4<Float>(1, 0.5, 0.5, 1)
        expectStoredHalfRGBA(
            result.sceneLinearRGBA,
            approximately: expectedLinear
        )
        expectBGRA8(
            result.presentedBGRA8,
            approximately: srgbEncodedBGRA8(from: expectedLinear.xyz)
        )

        let one = SIMD3<Float>(repeating: 1)
        let accidentallyToneMapped = expectedLinear.xyz * 8
            / (one + expectedLinear.xyz * 8)
        let wrongSurfaceBytes = srgbEncodedBGRA8(
            from: accidentallyToneMapped
        )
        #expect(byteDistance(result.presentedBGRA8, wrongSurfaceBytes) > 40)
    }

    @Test func maximumFiniteExposureRollsOverflowingProductsToWhite() throws {
        let renderer = try MetalHDRPipelineTestRenderer()
        let exposure = ManualExposure(multiplier: .greatestFiniteMagnitude)
        let result = try renderer.render(
            outputMode: .surface,
            exposure: exposure
        )

        // The largest accepted finite exposure pushes every positive channel
        // toward Reinhard's limiting value; the brightest product overflows.
        // The shader must produce white without `inf / inf` NaNs or subnormal
        // reciprocal behavior leaking into fixed-function conversion.
        let expectedPresentedBGRA8 = SIMD4<UInt8>(repeating: 255)
        #expect(result.presentedBGRA8 == expectedPresentedBGRA8)
    }
}

private func expectStoredHalfRGBA(_ actual: SIMD4<Float>, approximately expected: SIMD4<Float>, maximumHalfULPDistance: Int = 2) {
    // Positive half-float bit patterns are monotonically ordered. This compares
    // the precision the scene attachment actually stores, rather than imposing
    // an arbitrary decimal epsilon on GPU arithmetic.
    for componentIndex in 0..<4 {
        let actualHalf = Float16(actual[componentIndex])
        let expectedHalf = Float16(expected[componentIndex])
        let actualBitPattern = Int(actualHalf.bitPattern)
        let expectedBitPattern = Int(expectedHalf.bitPattern)
        let ulpDistance = abs(actualBitPattern - expectedBitPattern)
        #expect(ulpDistance <= maximumHalfULPDistance)
    }
}

private func expectBGRA8(_ actual: SIMD4<UInt8>, approximately expected: SIMD4<UInt8>, maximumByteDistance: Int = 1) {
    // Metal's fixed-function conversion may differ by one final quantization
    // step across GPUs, while any missing or duplicate transfer differs by
    // dozens of byte values in the selected validation colors.
    for componentIndex in 0..<4 {
        let actualComponent = Int(actual[componentIndex])
        let expectedComponent = Int(expected[componentIndex])
        #expect(
            abs(actualComponent - expectedComponent)
                <= maximumByteDistance
        )
    }
}

private func expectStoredHalfRGBSum(
    _ actual: SIMD4<Float>,
    _ first: SIMD4<Float>,
    _ second: SIMD4<Float>,
    maximumHalfULPDistance: Int = 4
) {
    for componentIndex in 0..<3 {
        let actualHalf = Float16(actual[componentIndex])
        let expectedHalf = Float16(
            first[componentIndex] + second[componentIndex]
        )
        let actualBitPattern = Int(actualHalf.bitPattern)
        let expectedBitPattern = Int(expectedHalf.bitPattern)
        let ulpDistance = abs(actualBitPattern - expectedBitPattern)
        #expect(ulpDistance <= maximumHalfULPDistance)
    }
    #expect(actual.w == 1)
}

private func linearBGRA8(from rgb: SIMD3<Float>) -> SIMD4<UInt8> {
    SIMD4<UInt8>(
        quantizedUNorm8(rgb.z),
        quantizedUNorm8(rgb.y),
        quantizedUNorm8(rgb.x),
        255
    )
}

private func srgbEncodedBGRA8(from displayLinearRGB: SIMD3<Float>) -> SIMD4<UInt8> {
    linearBGRA8(from: displayLinearRGB.applyingSRGBTransfer)
}

private func quantizedUNorm8(_ value: Float) -> UInt8 {
    let clamped = min(max(value, 0), 1)
    return UInt8((clamped * 255).rounded())
}

private func byteDistance(_ lhs: SIMD4<UInt8>, _ rhs: SIMD4<UInt8>) -> Int {
    (0..<4).reduce(into: 0) { distance, componentIndex in
        let lhsComponent = Int(lhs[componentIndex])
        let rhsComponent = Int(rhs[componentIndex])
        distance += abs(lhsComponent - rhsComponent)
    }
}

private extension SIMD3 where Scalar == Float {
    /// IEC 61966-2-1 transfer used by Metal's `_srgb` color attachment.
    var applyingSRGBTransfer: SIMD3<Float> {
        SIMD3<Float>(
            srgbEncode(x),
            srgbEncode(y),
            srgbEncode(z)
        )
    }

    private func srgbEncode(_ linear: Float) -> Float {
        let clamped = Swift.max(linear, 0)
        if clamped <= 0.0031308 {
            return clamped * 12.92
        }
        return 1.055 * pow(clamped, 1 / 2.4) - 0.055
    }
}

private extension SIMD4 where Scalar == Float {
    var xyz: SIMD3<Float> {
        SIMD3<Float>(x, y, z)
    }

    func replacingW(with replacement: Float) -> SIMD4<Float> {
        SIMD4<Float>(x, y, z, replacement)
    }
}
