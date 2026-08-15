/// Version of the complete procedural model and deterministic random contract.
///
/// Changing a distribution, phase equation, ordering rule, or random-stream
/// derivation requires a new case so saved systems never silently regenerate as
/// different systems.
nonisolated enum StarSystemGenerationModelVersion: UInt32, Codable, Equatable, Hashable, Sendable {
    case coreAccretionLiteV1 = 1
}
