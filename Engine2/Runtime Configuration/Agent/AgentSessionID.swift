import Foundation

/// Stable identity for one live transport-neutral agent-control session.
///
/// The vocabulary is intentionally open because applications and future remote
/// transports create sessions dynamically. This identity does not replace the
/// distinct ``SimulationSessionID`` that qualifies authoritative world time.
nonisolated struct AgentSessionID:
    Codable,
    Hashable,
    RawRepresentable,
    Sendable
{
    let rawValue: UUID

    /// Creates a fresh live-process agent session identity.
    init() {
        self.init(rawValue: UUID())
    }

    /// Restores or injects an already established session identity.
    init(rawValue: UUID) {
        self.rawValue = rawValue
    }
}
