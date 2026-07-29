import simd

/// Immutable, platform-neutral raw input state published by `InputRuntime`.
///
/// Pointer motion and scroll are cumulative within a runtime session. A
/// consumer can therefore skip intermediate publications and still derive the
/// complete delta from the last revision it consumed.
public nonisolated struct InputSnapshot: Equatable, Sendable {
    public let revision: InputRevision
    public let pointerPosition: SIMD2<Float>
    public let pointerMotionTotal: SIMD2<Float>
    public let scrollTotal: SIMD2<Float>
    public let pressedMouseButtons: Set<MouseButton>
    public let pressedKeys: Set<KeyboardKey>

    public static let empty = InputSnapshot(
        revision: .initial,
        pointerPosition: .zero,
        pointerMotionTotal: .zero,
        scrollTotal: .zero,
        pressedMouseButtons: [],
        pressedKeys: []
    )

    public init(
        revision: InputRevision,
        pointerPosition: SIMD2<Float>,
        pointerMotionTotal: SIMD2<Float>,
        scrollTotal: SIMD2<Float>,
        pressedMouseButtons: Set<MouseButton>,
        pressedKeys: Set<KeyboardKey>
    ) {
        self.revision = revision
        self.pointerPosition = pointerPosition
        self.pointerMotionTotal = pointerMotionTotal
        self.scrollTotal = scrollTotal
        self.pressedMouseButtons = pressedMouseButtons
        self.pressedKeys = pressedKeys
    }
}
