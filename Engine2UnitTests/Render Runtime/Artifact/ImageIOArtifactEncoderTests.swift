import CoreGraphics
import Foundation
import ImageIO
import simd
import Testing
import UniformTypeIdentifiers
@testable import Engine2

struct ImageIOArtifactEncoderTests {
    @Test func qualityRequiresFiniteClosedUnitIntervalAndProvidesValidatedPresets() throws {
        let minimum = try JPEGQuality(0)
        let ordinary = try JPEGQuality(0.375)
        let maximum = try JPEGQuality(1)
        #expect(minimum.value == 0)
        #expect(ordinary.value == 0.375)
        #expect(maximum.value == 1)

        #expect(throws: JPEGQualityError.notFinite) {
            try quality(.nan)
        }
        #expect(throws: JPEGQualityError.notFinite) {
            try quality(.infinity)
        }
        #expect(throws: JPEGQualityError.notFinite) {
            try quality(-.infinity)
        }
        #expect(throws: JPEGQualityError.outsideClosedUnitInterval) {
            try quality(-0.001)
        }
        #expect(throws: JPEGQualityError.outsideClosedUnitInterval) {
            try quality(1.001)
        }

        #expect(JPEGQuality.observation.value == 0.85)
        #expect(JPEGQuality.maximum.value == 1)
    }

    @Test(arguments: [0.0, 0.73])
    func encodesDecodableJPEGAndPreservesExactProvenance(_ qualityValue: Double) async throws {
        let size = try RenderPixelSize(width: 7, height: 5)
        let result = try makeResult(
            image: solidImage(
                size: size,
                blue: 29,
                green: 113,
                red: 211
            )
        )
        let quality = try JPEGQuality(qualityValue)
        let encoding = ImageArtifactEncoding.jpeg(quality: quality)

        let artifact = try await ImageIOArtifactEncoder().encode(
            result,
            as: encoding
        )

        #expect(artifact.encoding == encoding)
        #expect(!artifact.encodedData.isEmpty)
        let prefix = Array(artifact.encodedData.prefix(2))
        let suffix = Array(artifact.encodedData.suffix(2))
        #expect(prefix == [0xFF, 0xD8])
        #expect(suffix == [0xFF, 0xD9])

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
        #expect(artifact.encoding == encoding)
    }

    @Test func jpegPreservesTopLeftRowsAndInterpretsBGRA() async throws {
        let size = try RenderPixelSize(width: 128, height: 128)
        let sourceImage = try twoBandImage(size: size)
        let result = try makeResult(image: sourceImage)
        let artifact = try await ImageIOArtifactEncoder().encode(
            result,
            as: .jpeg(quality: .maximum)
        )

        let source = try #require(
            CGImageSourceCreateWithData(artifact.encodedData as CFData, nil)
        )
        let decodedImage = try #require(
            CGImageSourceCreateImageAtIndex(source, 0, nil)
        )
        let rgba = try drawTopLeftRGBA(decodedImage)

        // Sample far from the lossy boundary so only orientation and channel
        // interpretation can determine which dominant color appears here.
        let topOffset = rgbaOffset(
            x: size.width / 2,
            y: size.height / 4,
            width: size.width
        )
        let bottomOffset = rgbaOffset(
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

    @Test func pngIsLosslessTopLeftBGRAWithExactProvenance() async throws {
        let size = try RenderPixelSize(width: 8, height: 4)
        let result = try makeResult(
            image: twoBandImage(size: size)
        )

        let artifact = try await ImageIOArtifactEncoder().encode(
            result,
            as: .png
        )

        let signature = Array(artifact.encodedData.prefix(8))
        #expect(signature == [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        #expect(artifact.encoding == .png)
        #expect(artifact.sourceRequestID == result.requestID)
        #expect(artifact.sourceCursor == result.sourceCursor)
        #expect(artifact.viewpoint == result.viewpoint)
        #expect(artifact.renderSettings == result.settings)

        let source = try #require(
            CGImageSourceCreateWithData(artifact.encodedData as CFData, nil)
        )
        let typeIdentifier = try #require(CGImageSourceGetType(source))
        #expect(typeIdentifier as String == UTType.png.identifier)
        let decodedImage = try #require(
            CGImageSourceCreateImageAtIndex(source, 0, nil)
        )
        #expect(decodedImage.width == size.width)
        #expect(decodedImage.height == size.height)

        let rgba = try drawTopLeftRGBA(decodedImage)
        let topOffset = rgbaOffset(
            x: size.width / 2,
            y: size.height / 4,
            width: size.width
        )
        let bottomOffset = rgbaOffset(
            x: size.width / 2,
            y: size.height * 3 / 4,
            width: size.width
        )
        let topPixel = Array(rgba[topOffset..<(topOffset + 3)])
        let bottomPixel = Array(rgba[bottomOffset..<(bottomOffset + 3)])
        #expect(topPixel == [250, 20, 80])
        #expect(bottomPixel == [10, 100, 250])
    }

    @Test func completionWinsAfterEncodingIsInvokedByCancelledTask() async throws {
        let size = try RenderPixelSize(width: 1, height: 1)
        let result = try makeResult(
            image: solidImage(
                size: size,
                blue: 3,
                green: 5,
                red: 7
            )
        )

        let encoding = Task {
            withUnsafeCurrentTask { task in
                task?.cancel()
            }
            return try await ImageIOArtifactEncoder().encode(
                result,
                as: .png
            )
        }
        let artifact = try await encoding.value

        #expect(artifact.encoding == .png)
        #expect(artifact.sourceRequestID == result.requestID)
    }

    private func makeResult(image: RenderedBGRA8SRGBImage) throws -> OffscreenRenderResult {
        let requestUUID = UUID(
            uuidString: "00000000-0000-0000-0000-000000000301"
        )!
        let requestID = OffscreenRenderRequestID(rawValue: requestUUID)
        let sessionUUID = UUID(
            uuidString: "00000000-0000-0000-0000-000000000302"
        )!
        let sessionID = SimulationSessionID(rawValue: sessionUUID)
        let tick = SimulationTick(rawValue: 41)
        let cursor = SimulationCursor(
            sessionID: sessionID,
            tick: tick
        )
        let viewpointUUID = UUID(
            uuidString: "00000000-0000-0000-0000-000000000303"
        )!
        let viewpointID = RenderViewpointID(rawValue: viewpointUUID)
        let viewpointRevision = RenderViewpointRevision(rawValue: 43)
        let cameraPosition = SIMD3<Float>(3, 5, 7)
        let camera = Camera(
            position: cameraPosition,
            rotation: Transform.identityRotation,
            projection: .orthographic(
                height: 11,
                near: 0.25,
                far: 250
            )
        )
        let viewpoint = RenderViewpoint(
            id: viewpointID,
            revision: viewpointRevision,
            camera: camera
        )
        let exposure = ManualExposure(multiplier: 1.75)
        let settings = OffscreenRenderSettings(
            size: image.size,
            outputMode: .viewSpaceNormals,
            exposure: exposure
        )

        return OffscreenRenderResult(
            requestID: requestID,
            sourceCursor: cursor,
            viewpoint: viewpoint,
            settings: settings,
            image: image
        )
    }

    private func solidImage(
        size: RenderPixelSize,
        blue: UInt8,
        green: UInt8,
        red: UInt8
    ) throws -> RenderedBGRA8SRGBImage {
        var bytes = [UInt8]()
        bytes.reserveCapacity(size.bgra8ByteCount)

        for _ in 0..<size.pixelCount {
            bytes.append(contentsOf: [blue, green, red, 255])
        }

        let data = Data(bytes)
        return try RenderedBGRA8SRGBImage(
            size: size,
            bytes: data
        )
    }

    private func twoBandImage(size: RenderPixelSize) throws -> RenderedBGRA8SRGBImage {
        var bytes = [UInt8]()
        bytes.reserveCapacity(size.bgra8ByteCount)

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

        let data = Data(bytes)
        return try RenderedBGRA8SRGBImage(
            size: size,
            bytes: data
        )
    }

    private func drawTopLeftRGBA(_ image: CGImage) throws -> [UInt8] {
        let sRGBColorSpace = CGColorSpace(name: CGColorSpace.sRGB)
        let colorSpace = try #require(sRGBColorSpace)
        let bytesPerRow = image.width * 4
        var rgba = [UInt8](
            repeating: 0,
            count: bytesPerRow * image.height
        )
        // Big-endian words with premultiplied alpha last produce unambiguous
        // in-memory RGBA bytes, which match the offsets sampled below.
        let alphaInfo = CGBitmapInfo(
            rawValue: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        let bitmapInfo = CGBitmapInfo.byteOrder32Big.union(alphaInfo)

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
            let width = CGFloat(image.width)
            let height = CGFloat(image.height)
            let bounds = CGRect(x: 0, y: 0, width: width, height: height)
            context.draw(
                image,
                in: bounds
            )
            return true
        }
        try #require(drewImage)
        return rgba
    }

    private func rgbaOffset(x: Int, y: Int, width: Int) -> Int {
        (y * width + x) * 4
    }

    private func quality(_ value: Double) throws -> JPEGQuality {
        try JPEGQuality(value)
    }
}
