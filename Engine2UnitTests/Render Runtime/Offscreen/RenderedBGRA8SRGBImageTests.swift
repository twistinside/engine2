import Foundation
import Testing
@testable import Engine2

struct RenderedBGRA8SRGBImageTests {
    @Test func derivesTightlyPackedStrideAndTopLeftOrigin() throws {
        let size = try RenderPixelSize(width: 3, height: 2)
        let bytes = Data(repeating: 0x7F, count: 24)
        let image = try RenderedBGRA8SRGBImage(size: size, bytes: bytes)

        #expect(image.size == size)
        #expect(image.bytesPerRow == 12)
        #expect(image.origin == .topLeft)
        #expect(image.bytes == bytes)
    }

    @Test func rejectsShortAndLongPayloads() throws {
        let size = try RenderPixelSize(width: 2, height: 2)

        #expect(
            throws: RenderedBGRA8SRGBImageError.unexpectedByteCount(
                expected: 16,
                actual: 15
            )
        ) {
            try RenderedBGRA8SRGBImage(
                size: size,
                bytes: Data(repeating: 0, count: 15)
            )
        }
        #expect(
            throws: RenderedBGRA8SRGBImageError.unexpectedByteCount(
                expected: 16,
                actual: 17
            )
        ) {
            try RenderedBGRA8SRGBImage(
                size: size,
                bytes: Data(repeating: 0, count: 17)
            )
        }
    }

    @Test func detachesThroughDataValueSemanticsAndCopyOnWrite() throws {
        let size = try RenderPixelSize(width: 2, height: 1)
        var source = Data([0, 1, 2, 3, 4, 5, 6, 7])
        let image = try RenderedBGRA8SRGBImage(size: size, bytes: source)

        source[0] = 99
        #expect(image.bytes[0] == 0)

        var extractedCopy = image.bytes
        extractedCopy[1] = 88
        #expect(image.bytes[1] == 1)
        #expect(extractedCopy[1] == 88)
    }
}
