import Foundation

/// Identifies one observational diagnostics capture session.
///
/// This identity correlates samples and exported artifacts. It never
/// participates in runtime, simulation, input, render, or entity identity.
struct DiagnosticsSessionID: Codable, Equatable, Hashable, Sendable {
    let rawValue: UUID

    init(rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }
}
