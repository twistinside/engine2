import SwiftUI

/// Draws the symbolic object associated with one circular-reference transfer.
///
/// The symbol visualizes an Explorer projection. It does not represent an
/// authoritative spacecraft, physical size, or executed maneuver.
struct GravityTransferVehicleSymbol: View {
    let status: GravityTransferVehicleStatus

    private var tint: Color {
        switch status {
        case .awaitingDeparture:
            .cyan
        case .inFlight:
            .pink
        case .atArrivalReference:
            .orange
        }
    }

    private var accessibilityStatus: String {
        switch status {
        case .awaitingDeparture:
            "at the departure reference"
        case .inFlight:
            "on the transfer rail"
        case .atArrivalReference:
            "at the arrival reference"
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(.black.opacity(0.78))
            Circle()
                .stroke(tint.opacity(0.95), lineWidth: 2)
            Image(systemName: "paperplane.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(tint)
        }
        .frame(width: 26, height: 26)
        .shadow(color: tint.opacity(0.8), radius: 7)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Circular-reference vehicle \(accessibilityStatus)")
    }
}
