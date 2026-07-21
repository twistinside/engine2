/// Stable reporting metadata for the Simulation Runtime's component stores.
///
/// These identities describe inventory only. They are not storage keys and do
/// not form a registry that constrains future consumer-defined components.
enum ComponentStoreDiagnosticsID: String, Codable, CaseIterable, Sendable {
    case angularMotionAccumulator
    case angularVelocity
    case motion
    case position
    case renderable
    case rotation
    case scale
    case selectable
}
