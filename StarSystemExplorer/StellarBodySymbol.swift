import SwiftUI

/// Draws a symbolic host star with a warm radial surface and a size-proportional glow.
struct StellarBodySymbol: View {
    let diameter: CGFloat

    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [.white, .yellow, .orange],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: diameter * 0.6
                )
            )
            .frame(width: diameter, height: diameter)
            .shadow(color: .yellow.opacity(0.75), radius: diameter * 0.28)
    }
}
