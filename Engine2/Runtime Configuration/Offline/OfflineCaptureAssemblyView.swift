import SwiftUI

/// Presents the static identity and authority boundary of one offline assembly.
///
/// This UI does not claim to report live request progress, add a screen Render
/// Runtime, or expose the private
/// Simulation and Render owners. Exact capture clients continue to use the
/// assembly's sole ``POfflineCaptureTarget`` capability.
struct OfflineCaptureAssemblyView: View {
    let assembly: OfflineCaptureAssembly

    var body: some View {
        ContentUnavailableView {
            Label("Offline Capture Assembly", systemImage: "camera.aperture")
        } description: {
            VStack(spacing: 8) {
                Text(
                    "Initial cursor: tick \(assembly.initialCursor.tick.rawValue)."
                )
                Text(assembly.initialCursor.sessionID.rawValue.uuidString)
                    .font(.caption2)
                    .monospaced()
            }
        }
    }
}

#Preview {
    if let assembly = try? OfflineCaptureAssembly() {
        assembly
            .frame(width: 640, height: 360)
    } else {
        ContentUnavailableView(
            "Offline Capture Unavailable",
            systemImage: "exclamationmark.triangle"
        )
        .frame(width: 640, height: 360)
    }
}
