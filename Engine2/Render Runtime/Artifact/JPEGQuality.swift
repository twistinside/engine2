/// Validated normalized quality supplied to a JPEG artifact encoder.
///
/// The value follows Image I/O's closed `0...1` compression-quality domain.
/// It does not promise a particular file size or perceptual quality because
/// those outcomes remain properties of the platform JPEG implementation and
/// the encoded image content.
nonisolated struct JPEGQuality: Equatable, Hashable, Sendable {
    /// Balanced quality for machine observation and ordinary artifact exchange.
    static let observation = JPEGQuality(unchecked: 0.85)

    /// Highest quality requested from Image I/O's lossy JPEG encoder.
    static let maximum = JPEGQuality(unchecked: 1)

    /// Normalized Image I/O compression quality in the closed interval `0...1`.
    let value: Double

    /// Creates a validated finite normalized quality.
    init(_ value: Double) throws {
        guard value.isFinite else {
            throw JPEGQualityError.notFinite
        }
        guard (0...1).contains(value) else {
            throw JPEGQualityError.outsideClosedUnitInterval
        }

        self.value = value
    }

    /// Constructs constants whose source spelling proves the required invariant.
    private init(unchecked value: Double) {
        self.value = value
    }
}
