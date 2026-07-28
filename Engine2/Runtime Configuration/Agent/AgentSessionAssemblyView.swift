import SwiftUI

/// Presents the public initial identity and lifecycle boundary of one session.
///
/// The view does not expose the retained offline assembly or create transport,
/// control, or structured-observation behavior that the session does not own.
struct AgentSessionAssemblyView: View {
    let assembly: AgentSessionAssembly

    var body: some View {
        ContentUnavailableView {
            Label("Agent Session", systemImage: "network")
        } description: {
            VStack(spacing: 8) {
                Text("Initial request \(assembly.firstRequestID.sequence.rawValue)")
                    .monospacedDigit()
                Text(assembly.sessionID.rawValue.uuidString)
                    .font(.caption2)
                    .monospaced()
                Text(
                    "Simulation tick " +
                    "\(assembly.initialCursor.tick.rawValue)"
                )
            }
        }
    }
}

#Preview {
    if let assembly = try? AgentSessionAssembly() {
        assembly
            .frame(width: 640, height: 360)
    } else {
        ContentUnavailableView(
            "Agent Session Unavailable",
            systemImage: "exclamationmark.triangle"
        )
        .frame(width: 640, height: 360)
    }
}
