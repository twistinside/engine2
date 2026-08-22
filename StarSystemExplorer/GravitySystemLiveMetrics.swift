import SwiftUI

/// Presents the gravity metrics that change with the displayed ephemeris snapshot.
struct GravitySystemLiveMetrics: View {
    let model: GravitySystemExplorerModel

    private let presentation = GravitySystemPresentation()

    private var externalGravityMetric: (value: String, detail: String) {
        switch model.selectedGravityState {
        case .unavailable:
            let detail = model.selectedSourceID.map {
                "Gravity is unavailable at \(model.planetLabel(for: $0))."
            } ?? "No departure planet is selected."
            return ("—", detail)
        case .available(let metersPerSecondSquared):
            let detail = model.selectedSourceID.map {
                "At \(model.planetLabel(for: $0)); its own gravity is excluded"
            } ?? "The selected body’s own gravity is excluded"
            return (
                presentation.acceleration(metersPerSecondSquared: metersPerSecondSquared),
                detail
            )
        case .failed(let error):
            return ("Unavailable", presentation.gravityFieldFailureMessage(error))
        }
    }

    var body: some View {
        let gravityMetric = externalGravityMetric
        EagerAdaptiveGrid(minimumColumnWidth: 190, horizontalSpacing: 10, verticalSpacing: 10) {
            MetricTile(
                "Displayed epoch",
                value: presentation.epoch(model.currentEpoch),
                detail: "Reference-relative elapsed time",
                systemImage: "clock.fill",
                tint: .blue
            )
            MetricTile(
                "External gravity",
                value: gravityMetric.value,
                detail: gravityMetric.detail,
                systemImage: "arrow.down.to.line.compact",
                tint: .orange
            )
        }
    }
}
