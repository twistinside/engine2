import Charts
import SwiftUI

/// Expanded read-only view of bounded runtime cadence, work, and structure.
struct DiagnosticsDashboard: View {
    let presentation: DiagnosticsDashboardPresentation

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                cadenceSection
                metricSection("System durations", points: presentation.systemDurations)
                metricSection("Simulation backlog", points: presentation.backlog)
                metricSection("Render freshness", points: presentation.freshness)
                countSection("Presentation funnel", values: presentation.presentationFunnel)
                metricSection("Render phases", points: presentation.renderPhases)
                countSection("Runtime resources", values: presentation.resources)
                errorSection
            }
            .padding(20)
        }
        .frame(minWidth: 720, idealWidth: 940, minHeight: 540, idealHeight: 720)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityIdentifier("diagnostics.dashboard")
    }

    private var cadenceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Cadence lanes").font(.headline)
            if presentation.cadence.isEmpty {
                ContentUnavailableView("No cadence samples", systemImage: "waveform.path.ecg")
            } else {
                Chart(presentation.cadence) { point in
                    PointMark(
                        x: .value("Session nanoseconds", point.x),
                        y: .value("Lane", point.series.rawValue)
                    )
                    .foregroundStyle(by: .value("Lane", point.series.rawValue))
                }
                .frame(height: 180)
                metricTable(presentation.cadence)
            }
        }
        .accessibilityIdentifier("diagnostics.dashboard.cadence")
    }

    private func metricSection(
        _ title: String,
        points: [DiagnosticsMetricPoint]
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            if points.isEmpty {
                Text("No samples").foregroundStyle(.secondary)
            } else {
                Chart(points) { point in
                    LineMark(
                        x: .value("Sequence", point.x),
                        y: .value("Value", point.value)
                    )
                    .foregroundStyle(by: .value("Series", point.label))
                }
                .frame(height: 180)
                metricTable(points)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
    }

    private func countSection(
        _ title: String,
        values: [DiagnosticsNamedCount]
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            if values.isEmpty {
                Text("No inventory").foregroundStyle(.secondary)
            } else {
                Chart(values) { value in
                    BarMark(
                        x: .value("Count", value.count),
                        y: .value("Name", value.name)
                    )
                }
                .frame(height: max(120, CGFloat(values.count * 24)))
                Grid(alignment: .leading) {
                    ForEach(values) { value in
                        GridRow {
                            Text(value.name)
                            Text(value.count, format: .number).monospacedDigit()
                        }
                    }
                }
                .accessibilityLabel("\(title) textual values")
            }
        }
    }

    private var errorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Errors").font(.headline)
            if presentation.errors.isEmpty {
                Text("No retained errors").foregroundStyle(.secondary)
            } else {
                Grid(alignment: .leading) {
                    GridRow {
                        Text("Time").bold()
                        Text("Source").bold()
                        Text("Detail").bold()
                    }
                    ForEach(presentation.errors) { error in
                        GridRow {
                            Text(error.timestampNanoseconds, format: .number)
                            Text(error.source)
                            Text(error.detail)
                        }
                    }
                }
            }
        }
        .accessibilityIdentifier("diagnostics.dashboard.errors")
    }

    private func metricTable(_ points: [DiagnosticsMetricPoint]) -> some View {
        Grid(alignment: .leading) {
            GridRow {
                Text("Series").bold()
                Text("Sequence").bold()
                Text("Value").bold()
            }
            ForEach(Array(points.suffix(8))) { point in
                GridRow {
                    Text(point.label)
                    Text(point.x, format: .number).monospacedDigit()
                    Text(point.value, format: .number).monospacedDigit()
                }
            }
        }
        .font(.caption)
        .accessibilityLabel("Chart textual values")
    }
}

#if DEBUG
    #Preview("Empty dashboard") {
        DiagnosticsDashboard(presentation: .preview(.empty))
    }

    #Preview("Healthy dashboard") {
        DiagnosticsDashboard(presentation: .preview(.healthy))
    }

    #Preview("Backlog dashboard") {
        DiagnosticsDashboard(presentation: .preview(.backlog))
    }

    #Preview("Render error dashboard") {
        DiagnosticsDashboard(presentation: .preview(.renderError))
    }
#endif
