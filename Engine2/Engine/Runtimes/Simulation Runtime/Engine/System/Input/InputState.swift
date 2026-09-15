import simd

/// Authoritative Simulation-facing semantic input imported at fixed-step boundaries.
///
/// Held translation and interaction state remain available on every catch-up
/// step. Cumulative camera, selection, and fire publications become interval-local
/// values that ordered systems consume at most once before cleanup. Multiple fire
/// presses between imports coalesce into one request.
struct InputState {
    var translation = SIMD2<Float>.zero
    var isInteractionActive = false
    var isFireRequested = false
    var cameraOrbitDelta = SIMD2<Float>.zero
    var cameraZoomDelta: Float = 0
    var selectionPress: SelectionPress?

    private var consumptionBaseline = InputConsumptionBaseline.uninitialized

    /// Incorporates a newer immutable publication at a fixed-step boundary.
    mutating func ingest(_ snapshot: InputSnapshot) {
        guard accepts(snapshot) else {
            return
        }

        switch consumptionBaseline {
        case .uninitialized:
            guard accumulateTransients(
                cameraOrbitDelta: snapshot.cameraOrbitTotal,
                cameraZoomDelta: snapshot.cameraZoomTotal,
                selectionPress: snapshot.latestSelectionPress,
                hasNewSelectionPress: snapshot.selectionPressCount > 0,
                hasNewFirePress: snapshot.firePressCount > 0
            ) else {
                return
            }

        case let .consumed(consumedRevision, cameraOrbitTotal, cameraZoomTotal, selectionPressCount, firePressCount):
            guard snapshot.revision > consumedRevision else {
                return
            }

            if snapshot.revision.session == consumedRevision.session {
                guard snapshot.selectionPressCount >= selectionPressCount,
                      snapshot.firePressCount >= firePressCount,
                      accumulateTransients(
                        cameraOrbitDelta: snapshot.cameraOrbitTotal - cameraOrbitTotal,
                        cameraZoomDelta: snapshot.cameraZoomTotal - cameraZoomTotal,
                        selectionPress: snapshot.latestSelectionPress,
                        hasNewSelectionPress: snapshot.selectionPressCount > selectionPressCount,
                        hasNewFirePress: snapshot.firePressCount > firePressCount
                      ) else {
                    return
                }
            } else {
                guard accumulateTransients(
                    cameraOrbitDelta: snapshot.cameraOrbitTotal,
                    cameraZoomDelta: snapshot.cameraZoomTotal,
                    selectionPress: snapshot.latestSelectionPress,
                    hasNewSelectionPress: snapshot.selectionPressCount > 0,
                    hasNewFirePress: snapshot.firePressCount > 0
                ) else {
                    return
                }
            }
        }

        importPersistentState(from: snapshot)
    }

    /// Establishes a consumer cursor without replaying historical transients.
    mutating func rebase(to snapshot: InputSnapshot) {
        guard accepts(snapshot) else {
            return
        }

        clearTransientInput()
        importPersistentState(from: snapshot)
    }

    /// Clears interval-local commands while preserving held semantic intent.
    mutating func clearTransientInput() {
        cameraOrbitDelta = .zero
        cameraZoomDelta = 0
        selectionPress = nil
        isFireRequested = false
    }

    private func accepts(_ snapshot: InputSnapshot) -> Bool {
        let translationMagnitudeSquared = simd_length_squared(snapshot.translation)
        return snapshot.translation.isFinite
            && translationMagnitudeSquared.isFinite
            && translationMagnitudeSquared <= 1.0001
            && snapshot.cameraOrbitTotal.isFinite
            && snapshot.cameraZoomTotal.isFinite
            && (snapshot.selectionPressCount == 0 || snapshot.latestSelectionPress != nil)
    }

    private mutating func accumulateTransients(
        cameraOrbitDelta: SIMD2<Float>,
        cameraZoomDelta: Float,
        selectionPress: SelectionPress?,
        hasNewSelectionPress: Bool,
        hasNewFirePress: Bool
    ) -> Bool {
        let nextCameraOrbitDelta = self.cameraOrbitDelta + cameraOrbitDelta
        let nextCameraZoomDelta = self.cameraZoomDelta + cameraZoomDelta
        guard cameraOrbitDelta.isFinite,
              cameraZoomDelta.isFinite,
              nextCameraOrbitDelta.isFinite,
              nextCameraZoomDelta.isFinite,
              !hasNewSelectionPress || selectionPress != nil else {
            return false
        }

        self.cameraOrbitDelta = nextCameraOrbitDelta
        self.cameraZoomDelta = nextCameraZoomDelta
        isFireRequested = isFireRequested || hasNewFirePress
        if hasNewSelectionPress {
            self.selectionPress = selectionPress
        }
        return true
    }

    private mutating func importPersistentState(from snapshot: InputSnapshot) {
        translation = snapshot.translation
        isInteractionActive = snapshot.isInteractionActive
        consumptionBaseline = .consumed(
            revision: snapshot.revision,
            cameraOrbitTotal: snapshot.cameraOrbitTotal,
            cameraZoomTotal: snapshot.cameraZoomTotal,
            selectionPressCount: snapshot.selectionPressCount,
            firePressCount: snapshot.firePressCount
        )
    }
}
