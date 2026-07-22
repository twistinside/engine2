/// Monotonic identity for Render Runtime queue submission attempts.
struct RenderSubmissionID: Codable, Comparable, Hashable, Sendable {
    let rawValue: UInt64

    static let zero = RenderSubmissionID(rawValue: 0)

    func advanced() -> RenderSubmissionID {
        RenderSubmissionID(rawValue: rawValue + 1)
    }

    static func < (lhs: RenderSubmissionID, rhs: RenderSubmissionID) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
