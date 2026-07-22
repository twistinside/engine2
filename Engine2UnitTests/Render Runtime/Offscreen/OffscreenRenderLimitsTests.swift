import Testing
@testable import Engine2

struct OffscreenRenderLimitsTests {
    @Test func conservativeDefaultPublishesItsOverridablePolicy() {
        let limits = OffscreenRenderLimits.conservativeDefault

        #expect(limits.maxDimension == 8_192)
        #expect(limits.maxPixelCount == 16_777_216)
    }

    @Test func permitsExactDimensionAndPixelBoundaries() throws {
        let limits = OffscreenRenderLimits.conservativeDefault
        let dimensionBoundary = try RenderPixelSize(width: 8_192, height: 1)
        let pixelBoundary = try RenderPixelSize(width: 4_096, height: 4_096)

        #expect(limits.permits(dimensionBoundary))
        #expect(limits.permits(pixelBoundary))
    }

    @Test func rejectsEitherDimensionBeyondPolicy() throws {
        let limits = OffscreenRenderLimits.conservativeDefault
        let excessiveWidth = try RenderPixelSize(width: 8_193, height: 1)
        let excessiveHeight = try RenderPixelSize(width: 1, height: 8_193)

        #expect(!limits.permits(excessiveWidth))
        #expect(!limits.permits(excessiveHeight))
    }

    @Test func rejectsPixelCountBeyondPolicyWithinDimensionLimit() throws {
        let limits = OffscreenRenderLimits.conservativeDefault
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

        #expect(limits.permits(try RenderPixelSize(width: 10, height: 5)))
        #expect(!limits.permits(try RenderPixelSize(width: 10, height: 6)))
        #expect(!limits.permits(try RenderPixelSize(width: 11, height: 1)))
    }
}
