import CoreGraphics
import Foundation
import ImageIO
import simd
import Testing
import UniformTypeIdentifiers
@testable import Engine2

struct JPEGArtifactEncoderTests {
    @Test func qualityRequiresFiniteClosedUnitIntervalAndHasDeliberateDefaults() throws {
        #expect(try JPEGQuality(0).value == 0)
        #expect(try JPEGQuality(0.375).value == 0.375)
        #expect(try JPEGQuality(1).value == 1)

        #expect(throws: JPEGQualityError.notFinite) {
            try JPEGQuality(.nan)
        }
        #expect(throws: JPEGQualityError.notFinite) {
            try JPEGQuality(.infinity)
        }
        #expect(throws: JPEGQualityError.notFinite) {
            try JPEGQuality(-.infinity)
        }
        #expect(throws: JPEGQualityError.outsideClosedUnitInterval) {
            try JPEGQuality(-0.001)
        }
        #expect(throws: JPEGQualityError.outsideClosedUnitInterval) {
            try JPEGQuality(1.001)
        }

        #expect(JPEGQuality.observation.value == 0.85)
        #expect(JPEGQuality.maximum.value == 1)
        #expect(JPEGEncodingSettings().quality == .observation)
    }

    @Test func encodesDecodableJPEGAndPreservesExactProvenance() throws {
        let size = try RenderPixelSize(width: 7, height: 5)
        let result = try Self.makeResult(
            image: Self.solidImage(
                size: size,
                blue: 29,
                green: 113,
                red: 211
            )
        )
        let jpegSettings = JPEGEncodingSettings(quality: try JPEGQuality(0.73))

        let artifact = try JPEGArtifactEncoder().encode(
            result,
            settings: jpegSettings
        )

        #expect(artifact.format == .jpeg)
        #expect(!artifact.encodedData.isEmpty)
        #expect(Array(artifact.encodedData.prefix(2)) == [0xFF, 0xD8])
        #expect(Array(artifact.encodedData.suffix(2)) == [0xFF, 0xD9])

        let source = try #require(
            CGImageSourceCreateWithData(artifact.encodedData as CFData, nil)
        )
        let typeIdentifier = try #require(CGImageSourceGetType(source))
        #expect(typeIdentifier as String == UTType.jpeg.identifier)

        let decodedImage = try #require(
            CGImageSourceCreateImageAtIndex(source, 0, nil)
        )
        #expect(decodedImage.width == size.width)
        #expect(decodedImage.height == size.height)

        #expect(artifact.sourceRequestID == result.requestID)
        #expect(artifact.sourceCursor == result.sourceCursor)
        #expect(artifact.viewpoint == result.viewpoint)
        #expect(artifact.viewpoint.id == result.viewpoint.id)
        #expect(artifact.viewpoint.revision == result.viewpoint.revision)
        #expect(artifact.viewpoint.camera == result.viewpoint.camera)
        #expect(artifact.renderSettings == result.settings)
        #expect(artifact.jpegSettings == jpegSettings)
    }

    @Test func preservesTopLeftRowsAndInterpretsSourceBytesAsBGRA() throws {
        let size = try RenderPixelSize(width: 128, height: 128)
        let sourceImage = try Self.twoBandImage(size: size)
        let result = try Self.makeResult(image: sourceImage)
        let artifact = try JPEGArtifactEncoder().encode(
            result,
            settings: JPEGEncodingSettings(quality: .maximum)
        )

        let source = try #require(
            CGImageSourceCreateWithData(artifact.encodedData as CFData, nil)
        )
        let decodedImage = try #require(
            CGImageSourceCreateImageAtIndex(source, 0, nil)
        )
        let rgba = try Self.drawTopLeftRGBA(decodedImage)

        // Sample far from the lossy boundary so only orientation and channel
        // interpretation can determine which dominant color appears here.
        let topOffset = Self.rgbaOffset(
            x: size.width / 2,
            y: size.height / 4,
            width: size.width
        )
        let bottomOffset = Self.rgbaOffset(
            x: size.width / 2,
            y: size.height * 3 / 4,
            width: size.width
        )

        let topRed = Int(rgba[topOffset])
        let topGreen = Int(rgba[topOffset + 1])
        let topBlue = Int(rgba[topOffset + 2])
        let bottomRed = Int(rgba[bottomOffset])
        let bottomGreen = Int(rgba[bottomOffset + 1])
        let bottomBlue = Int(rgba[bottomOffset + 2])

        #expect(topRed > topBlue + 120)
        #expect(topRed > topGreen + 120)
        #expect(bottomBlue > bottomRed + 120)
        #expect(bottomBlue > bottomGreen + 120)
        #expect(bottomGreen > topGreen + 50)
    }

    private static func makeResult(
        image: RenderedBGRA8SRGBImage
    ) throws -> OffscreenRenderResult {
        let requestID = OffscreenRenderRequestID(
            rawValue: UUID(
                uuidString: "00000000-0000-0000-0000-000000000301"
            )!
        )
        let cursor = SimulationCursor(
            sessionID: SimulationSessionID(
                rawValue: UUID(
                    uuidString: "00000000-0000-0000-0000-000000000302"
                )!
            ),
            tick: SimulationTick(rawValue: 41)
        )
        let viewpoint = RenderViewpoint(
            id: RenderViewpointID(
                rawValue: UUID(
                    uuidString: "00000000-0000-0000-0000-000000000303"
                )!
            ),
            revision: RenderViewpointRevision(rawValue: 43),
            camera: Camera(
                position: SIMD3<Float>(3, 5, 7),
                orthographicHeight: 11,
                nearPlane: 0.25,
                farPlane: 250
            )
        )
        let settings = OffscreenRenderSettings(
            size: image.size,
            outputMode: .viewSpaceNormals,
            exposure: ManualExposure(multiplier: 1.75)
        )

        return OffscreenRenderResult(
            requestID: requestID,
            sourceCursor: cursor,
            viewpoint: viewpoint,
            settings: settings,
            image: image
        )
    }

    private static func solidImage(
        size: RenderPixelSize,
        blue: UInt8,
        green: UInt8,
        red: UInt8
    ) throws -> RenderedBGRA8SRGBImage {
        var bytes = [UInt8]()
        bytes.reserveCapacity(size.pixelCount * 4)

        for _ in 0..<size.pixelCount {
            bytes.append(contentsOf: [blue, green, red, 255])
        }

        return try RenderedBGRA8SRGBImage(
            size: size,
            bytes: Data(bytes)
        )
    }

    private static func twoBandImage(
        size: RenderPixelSize
    ) throws -> RenderedBGRA8SRGBImage {
        var bytes = [UInt8]()
        bytes.reserveCapacity(size.pixelCount * 4)

        for y in 0..<size.height {
            // The source contract is top-left BGRA: red occupies the first
            // rows and blue occupies the last rows. Distinct green levels tag
            // the bands independently, preventing a row flip and red/blue
            // channel swap from cancelling each other out in the assertions.
            let pixel: [UInt8] = y < size.height / 2
                ? [80, 20, 250, 255]
                : [250, 100, 10, 255]
            for _ in 0..<size.width {
                bytes.append(contentsOf: pixel)
            }
        }

        return try RenderedBGRA8SRGBImage(
            size: size,
            bytes: Data(bytes)
        )
    }

    private static func drawTopLeftRGBA(_ image: CGImage) throws -> [UInt8] {
        let colorSpace = try #require(
            CGColorSpace(name: CGColorSpace.sRGB)
        )
        let bytesPerRow = image.width * 4
        var rgba = [UInt8](
            repeating: 0,
            count: bytesPerRow * image.height
        )
        // Big-endian words with premultiplied alpha last produce unambiguous
        // in-memory RGBA bytes, which match the offsets sampled below.
        let bitmapInfo = CGBitmapInfo.byteOrder32Big.union(
            CGBitmapInfo(
                rawValue: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        )

        let drewImage = rgba.withUnsafeMutableBytes { buffer -> Bool in
            guard
                let baseAddress = buffer.baseAddress,
                let context = CGContext(
                    data: baseAddress,
                    width: image.width,
                    height: image.height,
                    bitsPerComponent: 8,
                    bytesPerRow: bytesPerRow,
                    space: colorSpace,
                    bitmapInfo: bitmapInfo.rawValue
                )
            else {
                return false
            }

            // Preserve the decoded CGImage's native scanline order in this raw
            // offscreen bitmap. A UI/view-coordinate flip here would reverse
            // the rows returned in `rgba` and test the helper, not the JPEG.
            context.draw(
                image,
                in: CGRect(
                    x: 0,
                    y: 0,
                    width: CGFloat(image.width),
                    height: CGFloat(image.height)
                )
            )
            return true
        }
        try #require(drewImage)
        return rgba
    }

    private static func rgbaOffset(x: Int, y: Int, width: Int) -> Int {
        (y * width + x) * 4
    }
}
