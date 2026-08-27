import Foundation

/// World-owned diagnostic history derived from authoritative fixed-step input.
///
/// This resource retains a bounded newest-first view for assembly UI tooling. It owns
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

        let entry = InputHistoryEntry(
            id: nextEntryID,
            frameIndex: frameIndex,
            frameCount: 1,
            tokens: tokens
        )
        entries.insert(entry, at: 0)
        nextEntryID += 1

        if entries.count > maximumEntryCount {
            entries.removeLast(entries.count - maximumEntryCount)
        }
    }

    private func tokens(for input: InputState) -> [String] {
        var tokens: [String] = []

        if input.translation != .zero {
            tokens.append(
                "Move x:\(format(signed: input.translation.x)) y:\(format(signed: input.translation.y))"
            )
        }

        if input.isInteractionActive {
            tokens.append("Interact")
        }

        if input.cameraOrbitDelta != .zero {
            tokens.append(
                "Orbit dx:\(format(signed: input.cameraOrbitDelta.x)) dy:\(format(signed: input.cameraOrbitDelta.y))"
            )
        }

        if input.cameraZoomDelta != 0 {
            tokens.append("Zoom:\(format(signed: input.cameraZoomDelta))")
        }

        if let selectionPress = input.selectionPress {
            tokens.append(
                "Select x:\(format(signed: selectionPress.normalizedPosition.x)) "
                    + "y:\(format(signed: selectionPress.normalizedPosition.y))"
            )
        }

        return tokens
    }

    private func format(signed value: Float) -> String {
        guard value.isFinite else {
            let text = String(value)
            return value.sign == .minus ? text : "+\(text)"
        }

        return String(
            format: "%+.2f",
            locale: Locale(identifier: "en_US_POSIX"),
            arguments: [value]
        )
    }
}
