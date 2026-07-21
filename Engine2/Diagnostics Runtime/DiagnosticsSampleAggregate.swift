/// Immutable lifetime aggregate for one sample kind within a capture session.
struct DiagnosticsSampleAggregate: Codable, Equatable, Sendable {
    let kind: DiagnosticsSampleKind
    let sampleCount: Int
    let durationSampleCount: Int
    let totalDurationNanoseconds: UInt64
    let minimumDurationNanoseconds: UInt64?
    let maximumDurationNanoseconds: UInt64?
}
