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

    /// Incorporates one host event and publishes the resulting immutable state.
    func receive(_ event: InputEvent) {
        guard isRunning else {
            return
        }

        switch event {
        case let .mouseButtonDown(button, position):
            pointerPosition = position
            pressedMouseButtons.insert(button)

        case let .mouseButtonUp(button, position):
            pointerPosition = position
            pressedMouseButtons.remove(button)

        case let .mouseDragged(delta, position):
            pointerPosition = position
            pointerMotionTotal += delta

        case let .scroll(delta):
            scrollTotal += delta

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
