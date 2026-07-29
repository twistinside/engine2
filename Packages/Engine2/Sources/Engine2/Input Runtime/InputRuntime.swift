import simd

/// Owns platform-neutral device state and publishes immutable input snapshots.
public final class InputRuntime: PInputEventSink, PInputSnapshotSource {
    private var revision = InputRevision.initial
    private var pointerPosition = SIMD2<Float>.zero
    private var pointerMotionTotal = SIMD2<Float>.zero
    private var scrollTotal = SIMD2<Float>.zero
    private var pressedMouseButtons = Set<MouseButton>()
    private var pressedKeys = Set<KeyboardKey>()

    public private(set) var isRunning = false
    public private(set) var latestInputSnapshot = InputSnapshot.empty

    public init() {}

    /// Begins a fresh publication session with neutral device state.
    public func start() {
        guard !isRunning else {
            return
        }

        isRunning = true
        revision = revision.startingNextSession()
        pointerPosition = .zero
        pointerMotionTotal = .zero
        scrollTotal = .zero
        pressedMouseButtons.removeAll(keepingCapacity: true)
        pressedKeys.removeAll(keepingCapacity: true)
        publishSnapshot()
    }

    /// Ends the session and publishes neutral held state before becoming idle.
    public func stop() {
        guard isRunning else {
            return
        }

        isRunning = false
        pressedMouseButtons.removeAll(keepingCapacity: true)
        pressedKeys.removeAll(keepingCapacity: true)
        revision = revision.advanced()
        publishSnapshot()
    }

    /// Incorporates one valid host event and publishes the resulting immutable state.
    ///
    /// Nonfinite coordinates or deltas, and deltas that would overflow a
    /// cumulative publication total, are ignored atomically so one malformed
    /// event cannot poison every later snapshot in the session.
    public func receive(_ event: InputEvent) {
        guard isRunning else {
            return
        }

        switch event {
        case let .mouseButtonDown(button, position):
            guard position.isFinite else {
                return
            }
            pointerPosition = position
            pressedMouseButtons.insert(button)

        case let .mouseButtonUp(button, position):
            guard position.isFinite else {
                return
            }
            pointerPosition = position
            pressedMouseButtons.remove(button)

        case let .mouseDragged(delta, position):
            let nextPointerMotionTotal = pointerMotionTotal + delta
            guard delta.isFinite,
                  position.isFinite,
                  nextPointerMotionTotal.isFinite else {
                return
            }
            pointerPosition = position
            pointerMotionTotal = nextPointerMotionTotal

        case let .scroll(delta):
            let nextScrollTotal = scrollTotal + delta
            guard delta.isFinite,
                  nextScrollTotal.isFinite else {
                return
            }
            scrollTotal = nextScrollTotal

        case let .keyDown(key):
            pressedKeys.insert(key)

        case let .keyUp(key):
            pressedKeys.remove(key)
        }

        revision = revision.advanced()
        publishSnapshot()
    }

    private func publishSnapshot() {
        latestInputSnapshot = InputSnapshot(
            revision: revision,
            pointerPosition: pointerPosition,
            pointerMotionTotal: pointerMotionTotal,
            scrollTotal: scrollTotal,
            pressedMouseButtons: pressedMouseButtons,
            pressedKeys: pressedKeys
        )
    }
}
