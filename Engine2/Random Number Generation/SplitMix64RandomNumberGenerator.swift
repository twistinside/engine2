/// Repeatable value-semantic SplitMix64 random-number producer.
///
/// Construction whitens the seed once before the first advancement. The
/// generator uses no system entropy or shared mutable state, so equal seeds
/// produce equal streams.
nonisolated struct SplitMix64RandomNumberGenerator: RandomNumberGenerator, Sendable {
    private var state: UInt64

    init(seed: UInt64) {
        state = Self.mixed(seed)
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        return Self.mixed(state)
    }

    private static func mixed(_ value: UInt64) -> UInt64 {
        var mixed = value
        mixed = (mixed ^ (mixed >> 30)) &* 0xBF58_476D_1CE4_E5B9
        mixed = (mixed ^ (mixed >> 27)) &* 0x94D0_49BB_1331_11EB
        return mixed ^ (mixed >> 31)
    }
}
