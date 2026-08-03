extension Duration {
    /// Converts a duration to double-precision milliseconds for timing reports.
    var milliseconds: Double {
        let components = components
        let milliseconds = Double(components.seconds) * 1_000
        let fractionalMilliseconds = Double(components.attoseconds) / 1_000_000_000_000_000
        return milliseconds + fractionalMilliseconds
    }

    /// Converts a duration to floating-point seconds at the boundary where
    /// fixed-step wall-clock time becomes simulation math.
    var seconds: Float {
        let components = components
        let seconds = Double(components.seconds)
        let attoseconds = Double(components.attoseconds) / 1_000_000_000_000_000_000
        return Float(seconds + attoseconds)
    }
}
