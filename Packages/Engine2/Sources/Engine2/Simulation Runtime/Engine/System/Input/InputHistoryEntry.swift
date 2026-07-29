/// One retained non-empty fixed-step input row for diagnostic presentation.
public struct InputHistoryEntry: Identifiable, Equatable {
    public let id: Int
    public let frameIndex: Int
    public var frameCount: Int
    public let tokens: [String]

    public var tokenText: String {
        tokens.joined(separator: "  ")
    }
}
