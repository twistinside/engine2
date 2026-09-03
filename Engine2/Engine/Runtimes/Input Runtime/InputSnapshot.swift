import simd

/// Immutable semantic intent published by `InputRuntime`.
///
/// Camera commands and selection counts are cumulative within a Runtime
/// session. A consumer can skip intermediate publications and still derive the
/// complete interval from the last revision it consumed. Held translation and
/// interaction state remain active until a later publication changes them.
nonisolated struct InputSnapshot: Equatable, Sendable {
    let revision: InputRevision
    let translation: SIMD2<Float>
    let isInteractionActive: Bool
    let cameraOrbitTotal: SIMD2<Float>
    let cameraZoomTotal: Float
    let latestSelectionPress: SelectionPress?
    let selectionPressCount: UInt64

    static let empty = InputSnapshot(
        revision: .initial,
        translation: .zero,
        isInteractionActive: false,
        cameraOrbitTotal: .zero,
        cameraZoomTotal: 0,
        latestSelectionPress: nil,
        selectionPressCount: 0
    )
}
