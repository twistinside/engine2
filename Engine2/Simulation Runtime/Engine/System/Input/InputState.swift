import simd

/// Authoritative simulation-facing input imported at fixed-step boundaries.
///
/// `InputState` rebases or derives transients from immutable Input Runtime
/// snapshots, then lets ordered input systems map, record, consume, and clear
/// them inside the Simulation Runtime. It never exposes mutable platform input
/// state across the runtime boundary.
struct InputState {
    /// Imported pointer state, including per-tick motion and scroll transients.
    struct Mouse {
        var position: SIMD2<Float> = .zero
        var delta: SIMD2<Float> = .zero
        var scrollDelta: SIMD2<Float> = .zero
        var buttons = Set<MouseButton>()
    }

    /// Persistent keyboard state from the latest imported input publication.
    struct Keyboard {
        var keys = Set<KeyboardKey>()
    }

    /// Higher-level transient commands derived from raw device state.
    ///
    /// Mapping systems populate these values for Simulation systems to consume
    /// in the same completed tick. Cleanup resets them with the raw transients.
    struct Actions {
        var cameraOrbitYawDelta: Float = 0
        var cameraZoomDelta: Float = 0
    }

    var mouse = Mouse()
    var keyboard = Keyboard()
    var actions = Actions()
    var history: [InputHistoryEntry] = []
    var historyLimit = 60

    private var frameIndex = 0
    private var nextHistoryID = 0
    private var consumptionBaseline = InputConsumptionBaseline.uninitialized

    /// Incorporates a newer immutable publication at a fixed-step boundary.
    mutating func ingest(_ snapshot: InputSnapshot) {
        switch consumptionBaseline {
        case .uninitialized:
            // A newly attached consumer starts at the beginning of the
            // snapshot's session. Explicit world replacement uses `rebase`
            // below when historical totals should instead be ignored.
            mouse.delta += snapshot.pointerMotionTotal
            mouse.scrollDelta += snapshot.scrollTotal

        case let .consumed(consumedRevision, pointerMotionTotal, scrollTotal):
            // Ignore repeated or stale latest-value reads.
            guard snapshot.revision > consumedRevision else {
                return
            }

            if snapshot.revision.session == consumedRevision.session {
                // Derive this consumer's transient input from cumulative totals.
                mouse.delta += snapshot.pointerMotionTotal - pointerMotionTotal
                mouse.scrollDelta += snapshot.scrollTotal - scrollTotal
            } else {
                // Cumulative totals restart from zero with each source
                // session, so only the new session's motion is imported.
                mouse.delta += snapshot.pointerMotionTotal
                mouse.scrollDelta += snapshot.scrollTotal
            }
        }

        importPersistentState(from: snapshot)
    }

    /// Establishes a consumer cursor without replaying historical transients.
    mutating func rebase(to snapshot: InputSnapshot) {
        mouse.delta = .zero
        mouse.scrollDelta = .zero
        importPersistentState(from: snapshot)
    }

    private mutating func importPersistentState(from snapshot: InputSnapshot) {
        mouse.position = snapshot.pointerPosition
        mouse.buttons = snapshot.pressedMouseButtons
        keyboard.keys = snapshot.pressedKeys
        consumptionBaseline = .consumed(
            revision: snapshot.revision,
            pointerMotionTotal: snapshot.pointerMotionTotal,
            scrollTotal: snapshot.scrollTotal
        )
    }

    mutating func recordHistoryFrame() {
        frameIndex += 1

        let tokens = currentHistoryTokens()
        guard !tokens.isEmpty else {
            return
        }

        if history.first?.tokens == tokens {
            history[0].frameCount += 1
            return
        }

        let entry = InputHistoryEntry(
            id: nextHistoryID,
            frameIndex: frameIndex,
            frameCount: 1,
            tokens: tokens
        )
        nextHistoryID += 1

        history.insert(entry, at: 0)
        if history.count > historyLimit {
            history.removeLast(history.count - historyLimit)
        }
    }

    mutating func clearTransientInput() {
        mouse.delta = .zero
        mouse.scrollDelta = .zero
        actions = Actions()
    }

    func currentHistoryTokens() -> [String] {
        var tokens: [String] = []

        tokens += mouse.buttons.sorted().map(\.displayName)

        if mouse.delta != .zero {
            tokens.append("Mouse dx:\(format(signed: mouse.delta.x)) dy:\(format(signed: mouse.delta.y))")
        }

        if mouse.scrollDelta != .zero {
            tokens.append("Wheel:\(format(signed: mouse.scrollDelta.y))")
        }

        tokens += keyboard.keys.sorted().map(\.displayName)

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
