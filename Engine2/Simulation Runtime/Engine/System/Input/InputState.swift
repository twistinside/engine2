//
//  InputState.swift
//  Engine2
//
//  Created by Codex on 6/14/26.
//

import simd

/// Simulation-owned input state derived from immutable Input Runtime snapshots.
struct InputState {
    struct Mouse {
        var position: SIMD2<Float> = .zero
        var delta: SIMD2<Float> = .zero
        var scrollDelta: SIMD2<Float> = .zero
        var buttons = Set<MouseButton>()
    }

    struct Keyboard {
        var keys = Set<KeyboardKey>()
    }

    struct Actions {
        var cameraOrbitDelta: SIMD2<Float> = .zero
        var cameraZoomDelta: Float = 0
    }

    var mouse = Mouse()
    var keyboard = Keyboard()
    var actions = Actions()
    var history: [InputHistoryEntry] = []
    var historyLimit = 60

    private var frameIndex = 0
    private var nextHistoryID = 0
    private var consumedRevision: InputRevision?
    private var pointerMotionTotal = SIMD2<Float>.zero
    private var scrollTotal = SIMD2<Float>.zero

    /// Incorporates a newer immutable publication at a fixed-step boundary.
    mutating func ingest(_ snapshot: InputSnapshot) {
        if let consumedRevision {
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
        } else {
            // A newly attached consumer starts at the beginning of the
            // snapshot's session. Explicit world replacement uses `rebase`
            // below when historical totals should instead be ignored.
            mouse.delta += snapshot.pointerMotionTotal
            mouse.scrollDelta += snapshot.scrollTotal
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
        pointerMotionTotal = snapshot.pointerMotionTotal
        scrollTotal = snapshot.scrollTotal
        consumedRevision = snapshot.revision
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
            tokens.append("Mouse \(Self.format(delta: mouse.delta))")
        }

        if mouse.scrollDelta != .zero {
            tokens.append("Wheel:\(Self.format(signed: mouse.scrollDelta.y))")
        }

        tokens += keyboard.keys.sorted().map(\.displayName)

        return tokens
    }

    private static func format(delta: SIMD2<Float>) -> String {
        "dx:\(format(signed: delta.x)) dy:\(format(signed: delta.y))"
    }

    private static func format(signed value: Float) -> String {
        let rounded = Int(value.rounded())
        if rounded >= 0 {
            return "+\(rounded)"
        } else {
            return "\(rounded)"
        }
    }
}
