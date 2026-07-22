/// One stable point shared by charts and their textual accessibility tables.
struct DiagnosticsMetricPoint: Identifiable, Equatable, Sendable {
    let id: Int
    let series: DiagnosticsMetricSeries
    let x: UInt64
    let value: Double
    let label: String
}
