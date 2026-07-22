import Testing
@testable import Engine2

@MainActor
struct HDRPresentationParametersTests {
    @Test func layoutMatchesOneMetalFloat4Lane() {
        // The presentation argument buffer is mirrored by one Metal `float4`.
        // Assert alignment as well as stride and offset so future field edits
        // cannot silently move the exposure multiplier across the GPU boundary.
        #expect(MemoryLayout<HDRPresentationParameters>.alignment == 16)
        #expect(MemoryLayout<HDRPresentationParameters>.size == 16)
        #expect(MemoryLayout<HDRPresentationParameters>.stride == 16)
        #expect(
            MemoryLayout<HDRPresentationParameters>.offset(
                of: \.exposurePadding
            ) == 0
        )
    }

    @Test func initializerPacksOnlyTheExposureMultiplier() {
        let parameters = HDRPresentationParameters(
            exposure: ManualExposure(multiplier: 2)
        )

        // Padding stays deterministically zero so captures and tests do not
        // mistake uninitialized bytes for an additional presentation control.
        #expect(parameters.exposurePadding == SIMD4<Float>(2, 0, 0, 0))
    }

    @Test func validationExposurePacksAsTheIdentityMultiplier() {
        let parameters = HDRPresentationParameters(exposure: .validation)

        #expect(parameters.exposurePadding == SIMD4<Float>(1, 0, 0, 0))
    }
}
