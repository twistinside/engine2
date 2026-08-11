import Foundation

/// Pinned SplitMix64 stream derived from one named generation domain.
///
/// This implementation is intentionally local and value-semantic. Swift's
/// randomized hashing, system entropy, collection iteration order, and wall
/// time never participate in generated output.
nonisolated struct StarSystemRandomStream: Sendable {
    private var state: UInt64

    init(
        seed: StarSystemSeed,
        modelVersion: StarSystemGenerationModelVersion,
        domain: StarSystemRandomDomain,
        discriminator: UInt64 = 0
    ) {
        var key = seed.rawValue ^ domain.rawValue
        key &+= UInt64(modelVersion.rawValue) &* 0xD6E8_FEB8_6659_FD93
        key ^= discriminator &* 0xA076_1D64_78BD_642F
        self.state = Self.mixed(key)
    }

    mutating func nextUInt64() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        return Self.mixed(state)
    }

    mutating func uniformUnit() -> Double {
        Double(nextUInt64() >> 11) * 0x1.0p-53
    }

    mutating func uniform(in range: ClosedRange<Double>) -> Double {
        precondition(
            range.lowerBound.isFinite && range.upperBound.isFinite,
            "A random floating-point range must be finite."
        )
        precondition(range.lowerBound <= range.upperBound, "A random range must be ordered.")
        return range.lowerBound + (range.upperBound - range.lowerBound) * uniformUnit()
    }

    mutating func integer(in range: ClosedRange<Int>) -> Int {
        precondition(range.lowerBound <= range.upperBound, "A random integer range must be ordered.")
        let width = UInt64(range.upperBound - range.lowerBound) + 1
        let rejectionThreshold = UInt64.max - UInt64.max % width
        var draw = nextUInt64()
        while draw >= rejectionThreshold {
            draw = nextUInt64()
        }
        return range.lowerBound + Int(draw % width)
    }

    mutating func normal(mean: Double = 0, standardDeviation: Double = 1) -> Double {
        precondition(mean.isFinite, "A normal-distribution mean must be finite.")
        precondition(
            standardDeviation.isFinite && standardDeviation >= 0,
            "A normal-distribution standard deviation must be finite and nonnegative."
        )
        let first = max(uniformUnit(), Double.leastNonzeroMagnitude)
        let second = uniformUnit()
        let standardNormal = sqrt(-2 * log(first)) * cos(2 * Double.pi * second)
        return mean + standardDeviation * standardNormal
    }

    mutating func logNormal10(median: Double, scatterDex: Double) -> Double {
        precondition(median.isFinite && median > 0, "A log-normal median must be positive and finite.")
        precondition(scatterDex.isFinite && scatterDex >= 0, "Log-normal scatter must be nonnegative and finite.")
        return median * pow(10, normal(standardDeviation: scatterDex))
    }

    mutating func rayleigh(scale: Double) -> Double {
        precondition(scale.isFinite && scale >= 0, "A Rayleigh scale must be finite and nonnegative.")
        return scale * sqrt(-2 * log(max(1 - uniformUnit(), Double.leastNonzeroMagnitude)))
    }

    mutating func powerLaw(in range: ClosedRange<Double>, exponent: Double) -> Double {
        precondition(range.lowerBound > 0 && range.upperBound >= range.lowerBound, "A power-law range must be positive.")
        precondition(exponent.isFinite, "A power-law exponent must be finite.")
        if abs(exponent - 1) < 1e-12 {
            return exp(uniform(in: log(range.lowerBound)...log(range.upperBound)))
        }
        let transformedExponent = 1 - exponent
        let lower = pow(range.lowerBound, transformedExponent)
        let upper = pow(range.upperBound, transformedExponent)
        return pow(uniform(in: min(lower, upper)...max(lower, upper)), 1 / transformedExponent)
    }

    private static func mixed(_ value: UInt64) -> UInt64 {
        var mixed = value
        mixed = (mixed ^ (mixed >> 30)) &* 0xBF58_476D_1CE4_E5B9
        mixed = (mixed ^ (mixed >> 27)) &* 0x94D0_49BB_1331_11EB
        return mixed ^ (mixed >> 31)
    }
}
