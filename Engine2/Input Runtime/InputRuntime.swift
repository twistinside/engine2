import simd

/// Owns physical device state and publishes mapped semantic input snapshots.
final class InputRuntime: PInputEventSink, PInputSnapshotSource {
    private let mappingConfiguration: InputMappingConfiguration

    private var revision = InputRevision.initial
    private var pointerPosition = SIMD2<Float>.zero
    private var viewportSize = SIMD2<Float>.zero
    private var cameraOrbitTotal = SIMD2<Float>.zero
    private var cameraZoomTotal: Float = 0
    private var latestSelectionPress: SelectionPress?
    private var selectionPressCount: UInt64 = 0
    private var pressedMouseButtons = Set<MouseButton>()
    private var pressedKeyCodes = Set<UInt16>()

    private(set) var isRunning = false
    private(set) var latestInputSnapshot = InputSnapshot.empty

    private var translation: SIMD2<Float> {
        let horizontal = axisValue(
            negativeKeyCodes: mappingConfiguration.leftKeyCodes,
            positiveKeyCodes: mappingConfiguration.rightKeyCodes
        )
        let vertical = axisValue(
            negativeKeyCodes: mappingConfiguration.downwardKeyCodes,
            positiveKeyCodes: mappingConfiguration.upwardKeyCodes
        )
        let candidate = SIMD2<Float>(horizontal, vertical)
        let magnitudeSquared = simd_length_squared(candidate)
        return magnitudeSquared > 1 ? simd_normalize(candidate) : candidate
    }

    init(mappingConfiguration: InputMappingConfiguration = .miningGame) {
        self.mappingConfiguration = mappingConfiguration
    }

    /// Begins a fresh publication session with neutral device state.
    func start() {
        guard !isRunning else {
            return
        }

        isRunning = true
        revision = revision.startingNextSession()
        pointerPosition = .zero
        viewportSize = .zero
        cameraOrbitTotal = .zero
        cameraZoomTotal = 0
        latestSelectionPress = nil
        selectionPressCount = 0
        pressedMouseButtons.removeAll(keepingCapacity: true)
        pressedKeyCodes.removeAll(keepingCapacity: true)
        publishSnapshot()
    }

    /// Ends the session and publishes neutral held state before becoming idle.
    func stop() {
        guard isRunning else {
            return
        }

        isRunning = false
        pressedMouseButtons.removeAll(keepingCapacity: true)
        pressedKeyCodes.removeAll(keepingCapacity: true)
        revision = revision.advanced()
        publishSnapshot()
    }

    /// Incorporates one valid host event and publishes the resulting immutable state.
    ///
    /// Nonfinite coordinates or deltas, and deltas that would overflow a
    /// cumulative publication total, are ignored atomically so one malformed
    /// event cannot poison every later snapshot in the session.
    func receive(_ event: InputEvent) {
        guard isRunning, revision.sequence < .max else {
            return
        }

        switch event {
        case .focusLost:
            guard !pressedMouseButtons.isEmpty || !pressedKeyCodes.isEmpty else {
                return
            }
            pressedMouseButtons.removeAll(keepingCapacity: true)
            pressedKeyCodes.removeAll(keepingCapacity: true)

        case let .mouseButtonDown(button, position, viewportSize):
            guard acceptsPointer(position: position, viewportSize: viewportSize) else {
                return
            }

            var nextSelectionPress = latestSelectionPress
            var nextSelectionPressCount = selectionPressCount
            if button == mappingConfiguration.selectionButton {
                guard selectionPressCount < .max,
                      let selectionPress = selectionPress(position: position, viewportSize: viewportSize) else {
                    return
                }
                nextSelectionPress = selectionPress
                nextSelectionPressCount += 1
            }

            pointerPosition = position
            self.viewportSize = viewportSize
            pressedMouseButtons.insert(button)
            latestSelectionPress = nextSelectionPress
            selectionPressCount = nextSelectionPressCount

        case let .mouseButtonUp(button, position, viewportSize):
            guard acceptsPointer(position: position, viewportSize: viewportSize) else {
                return
            }
            pointerPosition = position
            self.viewportSize = viewportSize
            pressedMouseButtons.remove(button)

        case let .mouseDragged(delta, position, viewportSize):
            let mappedDelta = delta * mappingConfiguration.pointerOrbitSensitivity
            let nextCameraOrbitTotal = cameraOrbitTotal + mappedDelta
            guard delta.isFinite,
                  mappedDelta.isFinite,
                  nextCameraOrbitTotal.isFinite,
                  acceptsPointer(position: position, viewportSize: viewportSize) else {
                return
            }
            pointerPosition = position
            self.viewportSize = viewportSize
            cameraOrbitTotal = nextCameraOrbitTotal

        case let .scroll(delta):
            let mappedDelta = delta.y * mappingConfiguration.scrollZoomSensitivity
            let nextCameraZoomTotal = cameraZoomTotal + mappedDelta
            guard delta.isFinite,
                  mappedDelta.isFinite,
                  nextCameraZoomTotal.isFinite else {
                return
            }
            cameraZoomTotal = nextCameraZoomTotal

        case let .keyDown(key):
            pressedKeyCodes.insert(key.keyCode)

        case let .keyUp(key):
            pressedKeyCodes.remove(key.keyCode)
        }

        revision = revision.advanced()
        publishSnapshot()
    }

    private func publishSnapshot() {
        latestInputSnapshot = InputSnapshot(
            revision: revision,
            translation: translation,
            isInteractionActive: !pressedKeyCodes.isDisjoint(with: mappingConfiguration.interactionKeyCodes),
            cameraOrbitTotal: cameraOrbitTotal,
            cameraZoomTotal: cameraZoomTotal,
            latestSelectionPress: latestSelectionPress,
            selectionPressCount: selectionPressCount
        )
    }

    private func axisValue(negativeKeyCodes: Set<UInt16>, positiveKeyCodes: Set<UInt16>) -> Float {
        let negativeValue: Float = pressedKeyCodes.isDisjoint(with: negativeKeyCodes) ? 0 : 1
        let positiveValue: Float = pressedKeyCodes.isDisjoint(with: positiveKeyCodes) ? 0 : 1
        return positiveValue - negativeValue
    }

    private func acceptsPointer(position: SIMD2<Float>, viewportSize: SIMD2<Float>) -> Bool {
        position.isFinite
            && viewportSize.isFinite
            && viewportSize.x > 0
            && viewportSize.y > 0
    }

    private func selectionPress(position: SIMD2<Float>, viewportSize: SIMD2<Float>) -> SelectionPress? {
        let normalizedPosition = simd_clamp(position / viewportSize, .zero, SIMD2<Float>(repeating: 1))
        return SelectionPress(
            normalizedPosition: normalizedPosition,
            aspectRatio: viewportSize.x / viewportSize.y
        )
    }
}
