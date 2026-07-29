import simd

/// Authoritative simulation-facing input imported at fixed-step boundaries.
///
/// `InputState` rebases or derives transients from immutable Input Runtime
/// snapshots, then lets ordered input systems map, consume, and clear them
/// inside the Simulation Runtime. Diagnostic retention belongs to the
/// World-owned ``InputHistory`` resource rather than this authoritative value.
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

    mutating func clearTransientInput() {
        mouse.delta = .zero
        mouse.scrollDelta = .zero
        actions = Actions()
    }
}
