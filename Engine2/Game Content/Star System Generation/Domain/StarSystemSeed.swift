/// Stable caller-selected seed for one generated star system.
///
/// Generation never consults wall time, Swift hashing, or process-global random
/// state. The seed is persisted beside the fully resolved result.
nonisolated struct StarSystemSeed: Codable, Equatable, Hashable, RawRepresentable, Sendable {
    let rawValue: UInt64
}
