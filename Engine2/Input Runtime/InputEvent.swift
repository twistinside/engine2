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

extension InputEvent {
    /// Closed event identity that intentionally excludes event payload content.
    var diagnosticsID: InputEventDiagnosticsID {
        switch self {
        case .mouseButtonDown: .mouseButtonDown
        case .mouseButtonUp: .mouseButtonUp
        case .mouseDragged: .mouseDragged
        case .scroll: .scroll
        case .keyDown: .keyDown
        case .keyUp: .keyUp
        }
    }

    /// Continuous events are sampled to prevent pointer cadence from dominating traces.
    var usesContinuousDiagnosticsSampling: Bool {
        switch self {
        case .mouseDragged, .scroll: true
        case .mouseButtonDown, .mouseButtonUp, .keyDown, .keyUp: false
        }
    }
}
