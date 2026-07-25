import simd

/// Owns platform-neutral device state and publishes immutable input snapshots.
@MainActor
final class InputRuntime: PInputEventSink, PInputSnapshotSource {
    private var revision = InputRevision.initial
    private var pointerPosition = SIMD2<Float>.zero
    private var pointerMotionTotal = SIMD2<Float>.zero
    private var scrollTotal = SIMD2<Float>.zero
    private var pressedMouseButtons = Set<MouseButton>()
    private var pressedKeys = Set<KeyboardKey>()

    private(set) var isRunning = false
    private(set) var latestInputSnapshot = InputSnapshot.empty

    /// Begins a fresh publication session with neutral device state.
    func start() {
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
    func stop() {
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
    func receive(_ event: InputEvent) {
        guard isRunning else {
            return
        }

        switch event {
        case let .mouseButtonDown(button, position):
            guard Self.isFinite(position) else {
                return
            }
            pointerPosition = position
            pressedMouseButtons.insert(button)

        case let .mouseButtonUp(button, position):
            guard Self.isFinite(position) else {
                return
            }
            pointerPosition = position
            pressedMouseButtons.remove(button)

        case let .mouseDragged(delta, position):
            let nextPointerMotionTotal = pointerMotionTotal + delta
            guard Self.isFinite(delta),
                  Self.isFinite(position),
                  Self.isFinite(nextPointerMotionTotal) else {
                return
            }
            pointerPosition = position
            pointerMotionTotal = nextPointerMotionTotal

        case let .scroll(delta):
            let nextScrollTotal = scrollTotal + delta
            guard Self.isFinite(delta),
                  Self.isFinite(nextScrollTotal) else {
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

    private static func isFinite(_ value: SIMD2<Float>) -> Bool {
        value.x.isFinite && value.y.isFinite
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
