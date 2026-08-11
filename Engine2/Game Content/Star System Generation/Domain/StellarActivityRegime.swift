/// Young-star rotation and high-energy-activity track used for atmosphere loss.
nonisolated enum StellarActivityRegime: UInt8, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case slow
    case median
    case fast
}
