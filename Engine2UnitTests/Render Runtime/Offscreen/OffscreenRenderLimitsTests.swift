import Testing
@testable import Engine2

struct OffscreenRenderLimitsTests {
    @Test func conservativePublishesItsOverridablePolicy() {
        let limits = OffscreenRenderLimits.conservative

        #expect(limits.maxDimension == 8_192)
        #expect(limits.maxPixelCount == 16_777_216)
    }

    @Test func permitsExactDimensionAndPixelBoundaries() throws {
        let limits = OffscreenRenderLimits.conservative
        let dimensionBoundary = try RenderPixelSize(width: 8_192, height: 1)
        let pixelBoundary = try RenderPixelSize(width: 4_096, height: 4_096)

        #expect(limits.permits(dimensionBoundary))
        #expect(limits.permits(pixelBoundary))
    }

    @Test func rejectsEitherDimensionBeyondPolicy() throws {
        let limits = OffscreenRenderLimits.conservative
        let excessiveWidth = try RenderPixelSize(width: 8_193, height: 1)
        let excessiveHeight = try RenderPixelSize(width: 1, height: 8_193)

        #expect(!limits.permits(excessiveWidth))
        #expect(!limits.permits(excessiveHeight))
    }

    @Test func rejectsPixelCountBeyondPolicyWithinDimensionLimit() throws {
        let limits = OffscreenRenderLimits.conservative
        let excessivePixels = try RenderPixelSize(width: 4_097, height: 4_096)

        #expect(excessivePixels.width < limits.maxDimension)
        #expect(excessivePixels.height < limits.maxDimension)
        #expect(!limits.permits(excessivePixels))
    }

    @Test func customPolicyUsesBothIndependentBounds() throws {
        let limits = OffscreenRenderLimits(
            maxDimension: 10,
            maxPixelCount: 50
        )
        let boundary = try RenderPixelSize(width: 10, height: 5)
        let excessivePixels = try RenderPixelSize(width: 10, height: 6)
        let excessiveDimension = try RenderPixelSize(width: 11, height: 1)

        #expect(limits.permits(boundary))
        #expect(!limits.permits(excessivePixels))
        #expect(!limits.permits(excessiveDimension))
    }
}
