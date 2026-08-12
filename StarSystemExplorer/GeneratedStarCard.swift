import SwiftUI

/// Displays every retained present-day and early-activity fact for the host star.
struct GeneratedStarCard: View {
    let star: GeneratedStar

    private let presentation = StarSystemPresentation()

    var body: some View {
        ExplorerCard(
            title: "Host Star",
            subtitle: presentation.label(for: star.activityRegime),
            systemImage: "sun.max.fill",
            tint: .yellow
        ) {
            HStack(spacing: 18) {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.white, .yellow, .orange],
                            center: .topLeading,
                            startRadius: 0,
                            endRadius: 38
                        )
                    )
                    .frame(width: 72, height: 72)
                    .shadow(color: .yellow.opacity(0.7), radius: 16)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 9)], spacing: 9) {
                    MetricTile(
                        "Mass", value: "\(presentation.number(star.mass.solarMasses)) M☉",
                        systemImage: "scalemass.fill", tint: .yellow)
                    MetricTile(
                        "Radius", value: "\(presentation.number(star.radius.solarRadii)) R☉",
                        systemImage: "circle.dashed", tint: .orange)
                    MetricTile(
                        "Luminosity", value: "\(presentation.number(star.luminosity.solarLuminosities)) L☉",
                        systemImage: "light.max", tint: .yellow)
                    MetricTile(
                        "Temperature", value: presentation.kelvin(star.effectiveTemperature),
                        systemImage: "thermometer.high", tint: .orange)
                    MetricTile(
                        "Age", value: "\(presentation.number(star.age.gigayears)) Gyr",
                        systemImage: "clock.arrow.circlepath", tint: .indigo)
                    MetricTile(
                        "Metallicity", value: "\(presentation.number(star.metallicityDex)) dex", systemImage: "atom",
                        tint: .teal)
                    MetricTile(
                        "XUV fraction", value: presentation.percent(star.xuvLuminosityFraction),
                        systemImage: "wave.3.right", tint: .purple)
                }
            }
        }
    }
}
