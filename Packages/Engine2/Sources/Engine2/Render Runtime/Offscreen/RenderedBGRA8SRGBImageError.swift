/// Describes why detached BGRA8-sRGB bytes cannot form a valid image value.
public nonisolated enum RenderedBGRA8SRGBImageError: Error, Equatable, Sendable {
    case unexpectedByteCount(expected: Int, actual: Int)
}
