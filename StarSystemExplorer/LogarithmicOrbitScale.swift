import Foundation

/// Maps nonnegative astronomical distances into a zero-safe logarithmic unit interval.
///
/// The `log1p` projection preserves an exact zero origin while compressing
/// progressively larger distances. Its inverse supplies evenly spaced labels.
nonisolated struct LogarithmicOrbitScale: Sendable {
    let lowerBound: Double
    let upperBound: Double

    init(lowerBound: Double, upperBound: Double) {
        precondition(
            lowerBound.isFinite && lowerBound >= 0,
            "The lower orbit bound must be finite and nonnegative."
        )
        precondition(
            upperBound.isFinite && upperBound > lowerBound,
            "The upper orbit bound must be finite and greater than the lower bound."
        )
        self.lowerBound = lowerBound
        self.upperBound = upperBound
    }

    func position(for value: Double) -> Double {
        let clamped = min(max(value, lowerBound), upperBound)
        return log1p(clamped - lowerBound) / log1p(upperBound - lowerBound)
    }

    func value(at position: Double) -> Double {
        let clamped = min(max(position, 0), 1)
        return lowerBound + expm1(log1p(upperBound - lowerBound) * clamped)
    }
}
