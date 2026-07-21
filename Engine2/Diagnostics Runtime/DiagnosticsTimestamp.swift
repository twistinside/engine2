/// Monotonic offset from the beginning of a diagnostics session.
///
/// The explicit nanosecond unit keeps exported arithmetic unambiguous. This
/// observational timestamp must not be used as simulation time.
struct DiagnosticsTimestamp: Codable, Comparable, Hashable, Sendable {
    let nanosecondsSinceSessionStart: UInt64

    static let zero = DiagnosticsTimestamp(nanosecondsSinceSessionStart: 0)

    static func < (lhs: DiagnosticsTimestamp, rhs: DiagnosticsTimestamp) -> Bool {
        lhs.nanosecondsSinceSessionStart < rhs.nanosecondsSinceSessionStart
    }
}
