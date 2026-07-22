/// Monotonic version of one output's presentation-owned viewpoint state.
///
/// The revision advances when that output changes or clears its own override.
/// When the output follows a Simulation-authored default, the Simulation cursor
/// attributes changes to that camera while this output revision may stay fixed.
nonisolated struct RenderViewpointRevision: Codable, Hashable, Comparable, Sendable {
    static let zero = RenderViewpointRevision(rawValue: 0)

    let rawValue: UInt64

    static func < (
        lhs: RenderViewpointRevision,
        rhs: RenderViewpointRevision
    ) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Returns the revision following one output-owned viewpoint change.
    func advanced() -> RenderViewpointRevision {
        precondition(rawValue < .max, "Render viewpoint revision overflowed.")
        return RenderViewpointRevision(rawValue: rawValue + 1)
    }
}
