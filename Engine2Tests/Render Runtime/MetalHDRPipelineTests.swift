import Foundation
import simd
import Testing
@testable import Engine2

@MainActor
struct MetalHDRPipelineTests {
    @Test func validationPBRSurvivesHDRAndPresentsWithOneSRGBTransfer() throws {
        let renderer = try MetalHDRPipelineTestRenderer()
        let result = try renderer.render(outputMode: .surface)

        // Independent normal-incidence reference for the fixed M3 validation
        // material and incident radiance (8, 4, 2). The red component must stay
        // above display white in the half-float scene phase.
        expectStoredHalfRGBA(
            result.sceneLinearRGBA,
            approximately: SIMD4<Float>(
                1.62974664,
                0.5092958,
                0.17825354,
                1
            )
        )
        #expect(result.sceneLinearRGBA.x > 1)

        // Presentation reads the already quantized half-float scene value,
        // multiplies by validation exposure 1, and applies Reinhard per channel.
        // The `_srgb` attachment then performs the sole transfer encoding; CPU
        // `getBytes` exposes those encoded BGRA bytes without a shader read.
        let sceneRGB = result.sceneLinearRGBA.xyz
        let reinhard = sceneRGB / (SIMD3<Float>(repeating: 1) + sceneRGB)
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

    @Test func normalDiagnosticBypassesExposureAndReinhard() throws {
        let renderer = try MetalHDRPipelineTestRenderer()
        let result = try renderer.render(
            outputMode: .viewSpaceNormals,
            normal: SIMD3<Float>(1, 0, 0),
            // A deliberately large exposure makes accidental use of the
            // surface presentation pipeline unmistakable.
            exposure: ManualExposure(multiplier: 8)
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

        let accidentallyToneMapped = expectedLinear.xyz * 8
            / (SIMD3<Float>(repeating: 1) + expectedLinear.xyz * 8)
        let wrongSurfaceBytes = srgbEncodedBGRA8(
            from: accidentallyToneMapped
        )
        #expect(byteDistance(result.presentedBGRA8, wrongSurfaceBytes) > 40)
    }

    @Test func maximumFiniteExposureRollsOverflowingProductsToWhite() throws {
        let renderer = try MetalHDRPipelineTestRenderer()
        let result = try renderer.render(
            outputMode: .surface,
            exposure: ManualExposure(multiplier: .greatestFiniteMagnitude)
        )

        // The largest accepted finite exposure pushes every positive channel
        // toward Reinhard's limiting value; the brightest product overflows.
        // The shader must produce white without `inf / inf` NaNs or subnormal
        // reciprocal behavior leaking into fixed-function conversion.
        #expect(result.presentedBGRA8 == SIMD4<UInt8>(repeating: 255))
    }
}

private func expectStoredHalfRGBA(
    _ actual: SIMD4<Float>,
    approximately expected: SIMD4<Float>,
    maximumHalfULPDistance: Int = 2
) {
    // Positive half-float bit patterns are monotonically ordered. This compares
    // the precision the scene attachment actually stores, rather than imposing
    // an arbitrary decimal epsilon on GPU arithmetic.
    for componentIndex in 0..<4 {
        let actualHalf = Float16(actual[componentIndex])
        let expectedHalf = Float16(expected[componentIndex])
        let ulpDistance = abs(
            Int(actualHalf.bitPattern) - Int(expectedHalf.bitPattern)
        )
        #expect(ulpDistance <= maximumHalfULPDistance)
    }
}

private func expectBGRA8(
    _ actual: SIMD4<UInt8>,
    approximately expected: SIMD4<UInt8>,
    maximumByteDistance: Int = 1
) {
    // Metal's fixed-function conversion may differ by one final quantization
    // step across GPUs, while any missing or duplicate transfer differs by
    // dozens of byte values in the selected validation colors.
    for componentIndex in 0..<4 {
        #expect(
            abs(Int(actual[componentIndex]) - Int(expected[componentIndex]))
                <= maximumByteDistance
        )
    }
}

private func linearBGRA8(
    from rgb: SIMD3<Float>
) -> SIMD4<UInt8> {
    SIMD4<UInt8>(
        quantizedUNorm8(rgb.z),
        quantizedUNorm8(rgb.y),
        quantizedUNorm8(rgb.x),
        255
    )
}

private func srgbEncodedBGRA8(
    from displayLinearRGB: SIMD3<Float>
) -> SIMD4<UInt8> {
    linearBGRA8(from: displayLinearRGB.applyingSRGBTransfer)
}

private func quantizedUNorm8(_ value: Float) -> UInt8 {
    let clamped = min(max(value, 0), 1)
    return UInt8((clamped * 255).rounded())
}

private func byteDistance(
    _ lhs: SIMD4<UInt8>,
    _ rhs: SIMD4<UInt8>
) -> Int {
    (0..<4).reduce(into: 0) { distance, componentIndex in
        distance += abs(Int(lhs[componentIndex]) - Int(rhs[componentIndex]))
    }
}

private extension SIMD3 where Scalar == Float {
    /// IEC 61966-2-1 transfer used by Metal's `_srgb` color attachment.
    var applyingSRGBTransfer: SIMD3<Float> {
        SIMD3<Float>(
            Self.srgbEncode(x),
            Self.srgbEncode(y),
            Self.srgbEncode(z)
        )
    }

    static func srgbEncode(_ linear: Float) -> Float {
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
}
