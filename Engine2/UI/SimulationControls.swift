import SwiftUI

/// Compact screen overlay for real-time playback and exact snapshot capture.
struct SimulationControls: View {
    let isSimulationRunning: Bool
    let isCapturingSnapshot: Bool
    let toggleSimulation: () -> Void
    let restartSimulation: () -> Void
    let captureSnapshot: () -> Void

    var body: some View {
        HStack {
            Button(
                "Restart Session",
                systemImage: "arrow.counterclockwise",
                action: restartSimulation
            )

            Button(
                isSimulationRunning
                    ? "Simulation Running"
                    : "Simulation Paused",
                systemImage: isSimulationRunning
                    ? "pause.fill"
                    : "play.fill",
                action: toggleSimulation
            )

            Button(
                isCapturingSnapshot
                    ? "Rendering 4K Snapshot…"
                    : "Save 4K Snapshot…",
                systemImage: isCapturingSnapshot
                    ? "hourglass"
                    : "square.and.arrow.down",
                action: captureSnapshot
            )
            .disabled(isCapturingSnapshot)
            .accessibilityInputLabels(["Save Snapshot"])
        }
        .font(.caption)
        .buttonStyle(.glass)
        .controlSize(.small)
    }
}

#Preview {
    SimulationControls(
        isSimulationRunning: true,
        isCapturingSnapshot: false,
        toggleSimulation: {},
        restartSimulation: {},
        captureSnapshot: {}
    )
    .padding()
}
