import Foundation

/// Opaque identity for one presentation-owned render viewpoint.
///
/// Viewpoints are created dynamically for windows, viewports, captures, and
/// tooling clients, so their identity vocabulary is intentionally open-ended
/// rather than represented by a closed enum.
nonisolated struct RenderViewpointID: Codable, Hashable, Sendable {
    let rawValue: UUID

    /// Creates a fresh identity for a newly owned viewpoint.
    init() {
        self.init(rawValue: UUID())
    }

    /// Restores or injects an already established viewpoint identity.
    init(rawValue: UUID) {
        self.rawValue = rawValue
    }
}
