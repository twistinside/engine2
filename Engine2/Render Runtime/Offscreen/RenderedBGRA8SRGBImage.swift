import Foundation

/// Detached, tightly packed BGRA8-sRGB pixels produced by an offscreen render.
///
/// The value contains no backend texture or mapped GPU allocation. Its byte
/// layout is blue, green, red, then alpha at four bytes per pixel. Rows contain
/// no padding and begin at Metal texel `(0, 0)`, the top-left of the image. RGB
/// bytes already contain the destination texture's sRGB transfer, so an
/// artifact encoder must not apply that transfer a second time. The current
/// presentation paths produce opaque alpha.
nonisolated struct RenderedBGRA8SRGBImage: Equatable, Sendable {
    let size: RenderPixelSize
    let bytesPerRow: Int
    let origin: RenderedImageOrigin
    let bytes: Data

    /// Validates and adopts exactly one tightly packed image payload.
    init(size: RenderPixelSize, bytes: Data) throws(RenderedBGRA8SRGBImageError) {
        guard bytes.count == size.bgra8ByteCount else {
            throw RenderedBGRA8SRGBImageError.unexpectedByteCount(
                expected: size.bgra8ByteCount,
                actual: bytes.count
            )
        }

        self.size = size
        self.bytesPerRow = size.bgra8BytesPerRow
        self.origin = .topLeft
        self.bytes = bytes
    }
}
