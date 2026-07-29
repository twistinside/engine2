import SwiftUI

/// Presents the current manual Simulation cursor and its exact one-tick advance control.
struct ManualSimulationControls: View {
    let currentCursor: SimulationCursor
    let isAdvancing: Bool
    let advanceOneTick: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Manual Simulation", systemImage: "forward.frame")
                .font(.headline)

            Text("Tick \(currentCursor.tick.rawValue)")
                .monospacedDigit()

            Text(currentCursor.sessionID.rawValue.uuidString)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Button(
                isAdvancing ? "Advancing…" : "Advance One Tick",
                systemImage: "forward.frame",
                action: advanceOneTick
            )
            .disabled(isAdvancing)
            .buttonStyle(.glass)
        }
        .padding()
        .glassEffect()
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: .bottomLeading
        )
    }
}
