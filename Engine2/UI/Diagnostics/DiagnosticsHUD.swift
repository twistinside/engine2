import SwiftUI

/// Compact always-on-top health readout for the latest diagnostic aggregates.
struct DiagnosticsHUD: View {
    let presentation: DiagnosticsHUDPresentation

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
            row("Collection", presentation.isCollectionEnabled ? "recording" : "paused")
            row("Simulation", presentation.simulationTick.map { "tick \($0)" } ?? "no steps")
            row("Backlog", formatNanoseconds(presentation.backlogNanoseconds))
            row("Freshness", presentation.renderFreshnessTicks.map { "\($0) ticks" } ?? "no frames")
            row("In flight", "\(presentation.inFlightFrameCount) / \(MetalRenderer.maximumFramesInFlight)")
            row(
                "Render CPU",
                presentation.averageRenderCPUNanoseconds.map(formatNanoseconds) ?? "no frames"
            )
            row("System work", "\(presentation.latestSystemWorkCount)")
            if let latestError = presentation.latestError {
                row("Error", latestError)
                    .foregroundStyle(.red)
            }
        }
        .font(.caption.monospacedDigit())
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("diagnostics.hud")
    }

    private func row(_ title: String, _ value: String) -> some View {
        GridRow {
            Text(title).foregroundStyle(.secondary)
            Text(value).lineLimit(1)
        }
    }

    private func formatNanoseconds(_ nanoseconds: UInt64) -> String {
        if nanoseconds >= 1_000_000 {
            return String(format: "%.2f ms", Double(nanoseconds) / 1_000_000)
        }
        return String(format: "%.1f µs", Double(nanoseconds) / 1_000)
    }
}

#Preview("Healthy diagnostics HUD") {
    DiagnosticsHUD(presentation: .preview)
        .padding()
        .frame(width: 320)
}
