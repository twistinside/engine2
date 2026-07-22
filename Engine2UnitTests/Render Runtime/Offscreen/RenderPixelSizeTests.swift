import Testing
@testable import Engine2

struct RenderPixelSizeTests {
    @Test func acceptsPositiveRepresentableDimensions() throws {
        let size = try RenderPixelSize(width: 3_840, height: 2_160)

        #expect(size.width == 3_840)
        #expect(size.height == 2_160)
        #expect(size.pixelCount == 8_294_400)
    }

    @Test func rejectsZeroAndNegativeWidths() {
        #expect(throws: RenderPixelSizeError.nonpositiveWidth(0)) {
            try RenderPixelSize(width: 0, height: 1)
        }
        #expect(throws: RenderPixelSizeError.nonpositiveWidth(-1)) {
            try RenderPixelSize(width: -1, height: 1)
        }
    }

    @Test func rejectsZeroAndNegativeHeights() {
        #expect(throws: RenderPixelSizeError.nonpositiveHeight(0)) {
            try RenderPixelSize(width: 1, height: 0)
        }
        #expect(throws: RenderPixelSizeError.nonpositiveHeight(-1)) {
            try RenderPixelSize(width: 1, height: -1)
        }
    }

    @Test func rejectsPixelCountOverflow() {
        let width = Int.max / 2 + 1

        #expect(
            throws: RenderPixelSizeError.pixelCountOverflow(
                width: width,
                height: 2
            )
        ) {
            try RenderPixelSize(width: width, height: 2)
        }
    }

    @Test func rejectsBGRABytesPerRowOverflow() {
        let width = Int.max / 4 + 1

        #expect(
            throws: RenderPixelSizeError.bytesPerRowOverflow(width: width)
        ) {
            try RenderPixelSize(width: width, height: 1)
        }
    }

    @Test func rejectsTotalBGRAByteCountOverflow() {
        let width = Int.max / 8
        let bytesPerRow = width * 4

        #expect(
            throws: RenderPixelSizeError.byteCountOverflow(
                bytesPerRow: bytesPerRow,
                height: 3
            )
        ) {
            try RenderPixelSize(width: width, height: 3)
        }
    }
}
