import Engine2
import Engine2AssemblySupport
import Engine2OfflineCaptureAssembly
import Foundation

/// Stable identity for one live transport-neutral agent-control session.
///
/// The vocabulary is intentionally open because applications and future remote
/// transports create sessions dynamically. This identity does not replace the
/// distinct ``SimulationSessionID`` that qualifies authoritative world time.
public nonisolated struct AgentSessionID: Codable, Hashable, RawRepresentable, Sendable {
    public let rawValue: UUID

    /// Creates a fresh live-process agent session identity.
    public init() {
        self.init(rawValue: UUID())
    }

    /// Restores or injects an already established session identity.
    public init(rawValue: UUID) {
        self.rawValue = rawValue
    }
}
