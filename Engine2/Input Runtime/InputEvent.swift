import simd

/// Platform-neutral input received from a host adapter by `InputRuntime`.
///
/// This is runtime ingress, not a peer-runtime publication contract. Peers
/// consume immutable `InputSnapshot` values instead.
enum InputEvent: Sendable {
    case mouseButtonDown(MouseButton, position: SIMD2<Float>)
    case mouseButtonUp(MouseButton, position: SIMD2<Float>)
    case mouseDragged(delta: SIMD2<Float>, position: SIMD2<Float>)
    case scroll(delta: SIMD2<Float>)
    case keyDown(KeyboardKey)
    case keyUp(KeyboardKey)
}
