/// Validation failures for JPEG's normalized lossy-compression quality.
nonisolated enum JPEGQualityError: Error, Equatable, Sendable {
    /// Quality must be a finite number so its encoding behavior is well-defined.
    case notFinite

    /// Quality must be in the closed normalized interval from zero through one.
    case outsideClosedUnitInterval
}
