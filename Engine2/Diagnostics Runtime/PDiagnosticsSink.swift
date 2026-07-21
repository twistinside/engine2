/// Narrow consumer boundary for typed runtime observations.
///
/// Producers report values through this protocol without depending on sample
/// retention, visualization, artifact export, or any other consumer lifecycle.
protocol PDiagnosticsSink: AnyObject {
    func record(_ sample: DiagnosticsSample)
}
