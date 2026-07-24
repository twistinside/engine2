/// Describes why a requested render size cannot represent a valid pixel grid.
nonisolated enum RenderPixelSizeError: Error, Equatable, Sendable {
    case nonpositiveWidth(Int)
    case nonpositiveHeight(Int)
    case pixelCountOverflow(width: Int, height: Int)
    case bytesPerRowOverflow(width: Int)
    case byteCountOverflow(bytesPerRow: Int, height: Int)
}
