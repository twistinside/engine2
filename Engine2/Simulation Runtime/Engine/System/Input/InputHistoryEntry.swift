/// One non-empty fixed-step input snapshot for the practice-mode history pane.
struct InputHistoryEntry: Identifiable, Equatable {
    let id: Int
    let frameIndex: Int
    var frameCount: Int
    var tokens: [String]

    var tokenText: String {
        tokens.joined(separator: "  ")
    }
}
