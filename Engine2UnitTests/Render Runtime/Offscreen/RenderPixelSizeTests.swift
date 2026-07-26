import Testing
@testable import Engine2

struct RenderPixelSizeTests {
    @Test func acceptsPositiveRepresentableDimensions() throws {
        let size = try RenderPixelSize(width: 3_840, height: 2_160)

        #expect(size == .uhd4K)
        #expect(size.width == 3_840)
        #expect(size.height == 2_160)
        #expect(size.pixelCount == 8_294_400)
        #expect(size.aspectRatio == Float(3_840) / Float(2_160))
        #expect(size.bgra8BytesPerRow == 15_360)
        #expect(size.bgra8ByteCount == 33_177_600)
    }

    @Test func acceptsSmallestAndLargestRepresentableBGRAGrids() throws {
        let smallest = try RenderPixelSize(width: 1, height: 1)
        let largestWidth = try RenderPixelSize(
            width: Int.max / 4,
            height: 1
        )
        let largestHeight = try RenderPixelSize(
            width: 1,
            height: Int.max / 4
        )

        #expect(smallest.pixelCount == 1)
        #expect(smallest.bgra8BytesPerRow == 4)
        #expect(smallest.bgra8ByteCount == 4)
        #expect(largestWidth.pixelCount == Int.max / 4)
        #expect(largestWidth.bgra8BytesPerRow == Int.max - 3)
        #expect(largestWidth.bgra8ByteCount == Int.max - 3)
        #expect(largestHeight.pixelCount == Int.max / 4)
        #expect(largestHeight.bgra8BytesPerRow == 4)
        #expect(largestHeight.bgra8ByteCount == Int.max - 3)
    }

    @Test func rejectsZeroAndNegativeWidths() {
        #expect(throws: RenderPixelSizeError.nonpositiveWidth(0)) {
            try size(width: 0, height: 1)
        }
        #expect(throws: RenderPixelSizeError.nonpositiveWidth(-1)) {
            try size(width: -1, height: 1)
        }
    }

    @Test func rejectsZeroAndNegativeHeights() {
        #expect(throws: RenderPixelSizeError.nonpositiveHeight(0)) {
            try size(width: 1, height: 0)
        }
        #expect(throws: RenderPixelSizeError.nonpositiveHeight(-1)) {
            try size(width: 1, height: -1)
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
            try size(width: width, height: 2)
        }
    }

    @Test func rejectsBGRABytesPerRowOverflow() {
        let width = Int.max / 4 + 1

        #expect(
            throws: RenderPixelSizeError.bytesPerRowOverflow(width: width)
        ) {
            try size(width: width, height: 1)
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
            try size(width: width, height: 3)
        }
    }

    private func size(width: Int, height: Int) throws -> RenderPixelSize {
        try RenderPixelSize(width: width, height: height)
    }
}
