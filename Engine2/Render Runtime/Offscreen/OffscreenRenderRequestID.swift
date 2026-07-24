import Foundation

/// Opaque identity for one exact offscreen rendering request.
///
/// Requests are created dynamically by applications, tools, and remote clients,
/// so their identity vocabulary is intentionally open-ended rather than a
/// closed enum.
nonisolated struct OffscreenRenderRequestID:
    Codable,
    Hashable,
    RawRepresentable,
    Sendable
{
    let rawValue: UUID

    /// Creates a fresh identity for a newly issued request.
    init() {
        self.init(rawValue: UUID())
    }

    /// Restores or injects an already established request identity.
    init(rawValue: UUID) {
        self.rawValue = rawValue
    }
}
