extension Duration {
    /// Converts a duration to double-precision seconds for physical simulation.
    var doublePrecisionSeconds: Double {
        let components = components
        let seconds = Double(components.seconds)
        let attoseconds = Double(components.attoseconds)
            / 1_000_000_000_000_000_000
        return seconds + attoseconds
    }

    /// Converts a duration to double-precision milliseconds for timing reports.
    var milliseconds: Double {
        doublePrecisionSeconds * 1_000
    }

    /// Converts a duration to floating-point seconds at the boundary where
    /// fixed-step wall-clock time becomes simulation math.
    var seconds: Float {
        Float(doublePrecisionSeconds)
    }
}
