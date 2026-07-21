/// Monotonic Render Runtime identity independent of Simulation ticks.
struct RenderFrameSequence: Codable, Comparable, Hashable, Sendable {
    let rawValue: UInt64

    static let zero = RenderFrameSequence(rawValue: 0)

    func advanced() -> RenderFrameSequence {
        RenderFrameSequence(rawValue: rawValue + 1)
    }

    static func < (lhs: RenderFrameSequence, rhs: RenderFrameSequence) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
