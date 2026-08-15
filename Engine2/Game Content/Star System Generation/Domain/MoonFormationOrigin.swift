/// Formation channel retained as physical provenance for one moon.
nonisolated enum MoonFormationOrigin: UInt8, Codable, Equatable, Hashable, Sendable {
    case circumplanetaryDisk
    case giantImpact
}
