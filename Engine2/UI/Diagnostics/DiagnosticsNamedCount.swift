/// Named structural or funnel count suitable for bars and text tables.
struct DiagnosticsNamedCount: Identifiable, Equatable, Sendable {
    var id: String { name }
    let name: String
    let count: Int
}
