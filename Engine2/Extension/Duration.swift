extension Duration {
    /// Converts a duration to seconds for double-precision Simulation math.
    var seconds: Double {
        let components = components
        let seconds = Double(components.seconds)
        let attoseconds = Double(components.attoseconds) / 1_000_000_000_000_000_000
        return seconds + attoseconds
    }

    /// Converts a duration to double-precision milliseconds for timing reports.
    var milliseconds: Double {
        let components = components
        let milliseconds = Double(components.seconds) * 1_000
        let fractionalMilliseconds = Double(components.attoseconds) / 1_000_000_000_000_000
        return milliseconds + fractionalMilliseconds
    }
}
