/// One immutable Input Runtime publication fact.
struct InputSnapshotDiagnostics: Codable, Equatable, Sendable {
    let revision: InputRevision
    let heldKeyCount: Int
    let heldMouseButtonCount: Int
}
