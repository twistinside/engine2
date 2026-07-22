/// Complete policy for deriving one JPEG artifact from a completed render.
nonisolated struct JPEGEncodingSettings: Equatable, Sendable {
    /// Lossy-compression quality passed directly to Image I/O.
    let quality: JPEGQuality

    /// Creates JPEG policy, defaulting to the balanced observation quality.
    init(quality: JPEGQuality = .observation) {
        self.quality = quality
    }
}
