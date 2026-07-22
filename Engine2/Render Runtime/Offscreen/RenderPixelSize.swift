/// Validated two-dimensional pixel extent for an offscreen render target.
///
/// Construction proves both dimensions are positive and that the pixel count,
/// tightly packed BGRA row length, and total BGRA byte count all fit in `Int`.
/// Callers may therefore use ``pixelCount`` without repeating overflow checks.
nonisolated struct RenderPixelSize: Equatable, Hashable, Sendable {
    let width: Int
    let height: Int

    /// Number of pixels in the validated rectangular extent.
    var pixelCount: Int {
        width * height
    }

    /// Creates a positive extent with representable pixel and BGRA byte counts.
    init(width: Int, height: Int) throws {
        guard width > 0 else {
            throw RenderPixelSizeError.nonpositiveWidth(width)
        }
        guard height > 0 else {
            throw RenderPixelSizeError.nonpositiveHeight(height)
        }

        let (_, overflowed) = width.multipliedReportingOverflow(by: height)
        guard !overflowed else {
            throw RenderPixelSizeError.pixelCountOverflow(
                width: width,
                height: height
            )
        }

        let (bytesPerRow, rowOverflowed) = width
            .multipliedReportingOverflow(by: 4)
        guard !rowOverflowed else {
            throw RenderPixelSizeError.bytesPerRowOverflow(width: width)
        }

        let (_, byteCountOverflowed) = bytesPerRow
            .multipliedReportingOverflow(by: height)
        guard !byteCountOverflowed else {
            throw RenderPixelSizeError.byteCountOverflow(
                bytesPerRow: bytesPerRow,
                height: height
            )
        }

        self.width = width
        self.height = height
    }
}
