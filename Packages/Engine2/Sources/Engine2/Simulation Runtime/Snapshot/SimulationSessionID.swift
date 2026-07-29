import Foundation

/// Opaque identity for one uninterrupted authoritative Simulation timeline.
///
/// A Simulation Runtime preserves this value while advancing one world and
/// replaces it whenever rebuilding, restoring, rewinding, or forking could
/// make the same tick number describe different authoritative state.
public nonisolated struct SimulationSessionID: Codable, Hashable, RawRepresentable, Sendable {
    public let rawValue: UUID

    /// Creates a fresh identity for a new authoritative Simulation timeline.
    public init() {
        self.init(rawValue: UUID())
    }

    /// Restores or injects an already established session identity.
    public init(rawValue: UUID) {
        self.rawValue = rawValue
    }
}
