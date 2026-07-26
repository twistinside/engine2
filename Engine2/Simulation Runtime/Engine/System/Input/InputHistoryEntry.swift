/// One retained non-empty fixed-step input row for diagnostic presentation.
struct InputHistoryEntry: Identifiable, Equatable {
    let id: Int
    let frameIndex: Int
    var frameCount: Int
    let tokens: [String]

    var tokenText: String {
        tokens.joined(separator: "  ")
    }
}
