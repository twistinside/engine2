/// Closed diagnostic identity for platform-neutral Input Runtime ingress.
enum InputEventDiagnosticsID: String, Codable, CaseIterable, Sendable {
    case mouseButtonDown
    case mouseButtonUp
    case mouseDragged
    case scroll
    case keyDown
    case keyUp
}
