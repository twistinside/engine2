/// Low-cardinality error row detached from framework error instances.
struct DiagnosticsErrorPresentation: Identifiable, Equatable, Sendable {
    let id: Int
    let timestampNanoseconds: UInt64
    let source: String
    let detail: String
}
