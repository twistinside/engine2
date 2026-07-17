import simd

/// Immutable, platform-neutral raw input state published by `InputRuntime`.
///
/// Pointer motion and scroll are cumulative within a runtime session. A
/// consumer can therefore skip intermediate publications and still derive the
/// complete delta from the last revision it consumed.
struct InputSnapshot: Equatable, Sendable {
    let revision: InputRevision
    let pointerPosition: SIMD2<Float>
    let pointerMotionTotal: SIMD2<Float>
    let scrollTotal: SIMD2<Float>
    let pressedMouseButtons: Set<MouseButton>
    let pressedKeys: Set<KeyboardKey>

    static let empty = InputSnapshot(
        revision: .initial,
        pointerPosition: .zero,
        pointerMotionTotal: .zero,
        scrollTotal: .zero,
        pressedMouseButtons: [],
        pressedKeys: []
    )
}
