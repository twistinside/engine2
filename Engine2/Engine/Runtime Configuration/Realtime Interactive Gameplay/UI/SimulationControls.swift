import SwiftUI

/// Compact screen overlay for real-time playback controls.
struct SimulationControls: View {
    let isSimulationRunning: Bool
    let toggleSimulation: () -> Void
    let restartSimulation: () -> Void

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
        }
        .font(.caption)
        .buttonStyle(.glass)
        .controlSize(.small)
    }
}

#Preview {
    SimulationControls(
        isSimulationRunning: true,
        toggleSimulation: {},
        restartSimulation: {}
    )
    .padding()
}
