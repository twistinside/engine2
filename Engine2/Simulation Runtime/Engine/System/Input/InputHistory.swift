/// World-owned diagnostic history derived from authoritative fixed-step input.
///
/// This resource retains a bounded newest-first view for App tooling. It owns
/// presentation-oriented token formatting, fixed-step numbering, and
/// coalescing independently of ``InputState``'s authoritative imported state.
struct InputHistory {
    /// Newest-first non-empty input rows exposed read-only to diagnostics.
    private(set) var entries: [InputHistoryEntry] = []

    /// Maximum retained rows. Zero deliberately disables retention.
    let maximumEntryCount: Int

    private var frameIndex = 0
    private var nextEntryID = 0

    init(maximumEntryCount: Int) {
        precondition(maximumEntryCount >= 0, "Input history capacity cannot be negative.")
        self.maximumEntryCount = maximumEntryCount
    }

    /// Records one fixed-step input value without mutating authoritative input.
    mutating func record(input: InputState) {
        frameIndex += 1

        let tokens = tokens(for: input)
        guard !tokens.isEmpty, maximumEntryCount > 0 else {
            return
        }

        if let firstEntry = entries.first,
           firstEntry.tokens == tokens,
           firstEntry.frameIndex + firstEntry.frameCount == frameIndex {
            entries[0].frameCount += 1
            return
        }

        entries.insert(
            InputHistoryEntry(
                id: nextEntryID,
                frameIndex: frameIndex,
                frameCount: 1,
                tokens: tokens
            ),
            at: 0
        )
        nextEntryID += 1

        if entries.count > maximumEntryCount {
            entries.removeLast(entries.count - maximumEntryCount)
        }
    }

    private func tokens(for input: InputState) -> [String] {
        var tokens: [String] = []

        tokens += input.mouse.buttons.sorted().map(\.displayName)

        if input.mouse.delta != .zero {
            tokens.append("Mouse dx:\(format(signed: input.mouse.delta.x)) dy:\(format(signed: input.mouse.delta.y))")
        }

        if input.mouse.scrollDelta != .zero {
            tokens.append("Wheel:\(format(signed: input.mouse.scrollDelta.y))")
        }

        tokens += input.keyboard.keys.sorted().map(\.displayName)

        return tokens
    }

    private func format(signed value: Float) -> String {
        let rounded = value.rounded()
        guard let integer = Int(exactly: rounded) else {
            let text = String(value)
            return value.sign == .minus ? text : "+\(text)"
        }

        return integer >= 0 ? "+\(integer)" : "\(integer)"
    }
}
