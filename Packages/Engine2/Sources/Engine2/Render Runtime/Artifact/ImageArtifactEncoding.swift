/// Complete, format-specific policy for one encoded image artifact.
///
/// Keeping the format and its associated settings in one closed value prevents
/// invalid combinations such as requesting PNG while carrying JPEG quality.
/// Future formats can add their own validated policy without widening every
/// request into a bag of unrelated optional settings.
public nonisolated enum ImageArtifactEncoding: Equatable, Hashable, Sendable {
    /// JPEG output using Image I/O's validated normalized quality.
    case jpeg(quality: JPEGQuality)

    /// Lossless PNG output from the same opaque sRGB source pixels.
    case png
}
