/// One sampled Input Runtime ingress fact.
struct InputReceiveDiagnostics: Codable, Equatable, Sendable {
    let eventID: InputEventDiagnosticsID
    let revision: InputRevision
}
