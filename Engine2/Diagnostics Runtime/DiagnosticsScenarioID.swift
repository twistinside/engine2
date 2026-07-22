/// Repository-owned deterministic scenarios understood by capture tooling.
enum DiagnosticsScenarioID: String, Codable, CaseIterable, Sendable {
    case baselineSixBall = "baseline-six-ball"
    case interactiveAppSession = "interactive-app-session"
}
