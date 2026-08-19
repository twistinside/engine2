/// Supported mappings from wall-clock seconds to the explorer's displayed epoch.
///
/// These rates affect display-only playback. They do not change Simulation time,
/// rail definitions, propagation rules, or the generated gravity model.
nonisolated enum GravitySystemPlaybackRate: Double, CaseIterable, Identifiable, Sendable {
    case dayPerSecond = 86_400
    case thirtyDaysPerSecond = 2_592_000
    case yearPerSecond = 31_557_600
    case tenYearsPerSecond = 315_576_000

    var id: Self { self }

    var title: String {
        switch self {
        case .dayPerSecond:
            "1 day/s"
        case .thirtyDaysPerSecond:
            "30 days/s"
        case .yearPerSecond:
            "1 year/s"
        case .tenYearsPerSecond:
            "10 years/s"
        }
    }
}
