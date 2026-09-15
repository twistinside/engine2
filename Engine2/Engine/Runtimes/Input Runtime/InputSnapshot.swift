import simd

/// Immutable semantic intent published by `InputRuntime`.
///
/// Camera totals and press counts are cumulative within a Runtime
/// session. A consumer can skip intermediate publications and still derive the
/// camera interval and detect new presses. Simulation coalesces multiple selection
/// or fire presses into one request per import interval. Held translation and
/// interaction state remain active until a later publication changes them.
nonisolated struct InputSnapshot: Equatable, Sendable {
    let revision: InputRevision
    let translation: SIMD2<Float>
    let isInteractionActive: Bool
    let cameraOrbitTotal: SIMD2<Float>
    let cameraZoomTotal: Float
    let latestSelectionPress: SelectionPress?
    let selectionPressCount: UInt64
    /// Cumulative requests; Simulation decides whether and how the selected entity acts.
    let firePressCount: UInt64

    static let empty = InputSnapshot(
        revision: .initial,
        translation: .zero,
        isInteractionActive: false,
        cameraOrbitTotal: .zero,
        cameraZoomTotal: 0,
        latestSelectionPress: nil,
        selectionPressCount: 0,
        firePressCount: 0
    )
}
