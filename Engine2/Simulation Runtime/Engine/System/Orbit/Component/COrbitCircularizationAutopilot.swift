/// Persistent circularization authority for one dynamically integrated entity.
///
/// The request-scoped command only enters this state. An engaged state latches
/// its direction so the multi-tick burn cannot reverse when the cheaper ideal
/// target changes during the maneuver.
enum COrbitCircularizationAutopilot: PComponent {
    /// Latched planar direction for one circularization maneuver.
    nonisolated enum Direction: Codable, Equatable, Sendable {
        case clockwise
        case counterclockwise
    }

    case idle
    case engaged(direction: Direction)

    var direction: Direction? {
        switch self {
        case .idle:
            return nil
        case let .engaged(direction):
            return direction
        }
    }

    var isEngaged: Bool {
        direction != nil
    }
}
