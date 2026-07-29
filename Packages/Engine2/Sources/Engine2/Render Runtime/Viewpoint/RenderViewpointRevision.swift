/// Monotonic version of one output's presentation-owned viewpoint state.
///
/// The revision advances when that output changes or clears its own override.
/// When the output follows a Simulation-authored default, the Simulation cursor
/// attributes changes to that camera while this output revision may stay fixed.
public nonisolated struct RenderViewpointRevision: Codable, Hashable, RawRepresentable, Sendable {
    public static let zero = RenderViewpointRevision(rawValue: 0)

    public let rawValue: UInt64

    public init(rawValue: UInt64) {
        self.rawValue = rawValue
    }

    /// Returns the revision following one output-owned viewpoint change.
    public func advanced() -> RenderViewpointRevision {
        precondition(rawValue < .max, "Render viewpoint revision overflowed.")
        return RenderViewpointRevision(rawValue: rawValue + 1)
    }
}

extension RenderViewpointRevision: Comparable {
    public static func < (lhs: RenderViewpointRevision, rhs: RenderViewpointRevision) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
