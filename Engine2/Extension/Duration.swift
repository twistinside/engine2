extension Duration {
    /// Converts a duration to floating-point seconds at the boundary where
    /// fixed-step wall-clock time becomes simulation math.
    var seconds: Float {
        let components = components
        let seconds = Double(components.seconds)
        let attoseconds = Double(components.attoseconds) / 1_000_000_000_000_000_000
        return Float(seconds + attoseconds)
    }

    /// Returns a nonnegative nanosecond count for diagnostic artifacts.
    ///
    /// Negative injected-clock deltas clamp to zero. Extremely large values
    /// saturate instead of wrapping into a plausible short duration.
    var diagnosticsNanoseconds: UInt64 {
        guard self > .zero else {
            return 0
        }

        let components = components
        guard let wholeSeconds = UInt64(exactly: components.seconds) else {
            return .max
        }

        let (secondsAsNanoseconds, secondsOverflowed) = wholeSeconds
            .multipliedReportingOverflow(by: 1_000_000_000)
        guard !secondsOverflowed else {
            return .max
        }

        let fractionalNanoseconds = UInt64(components.attoseconds / 1_000_000_000)
        let (result, additionOverflowed) = secondsAsNanoseconds
            .addingReportingOverflow(fractionalNanoseconds)
        return additionOverflowed ? .max : result
    }
}
