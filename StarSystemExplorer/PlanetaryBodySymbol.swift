import SwiftUI

/// Draws a symbolic body whose fill, atmosphere halo, and water rim preserve separate physical axes.
struct PlanetaryBodySymbol: View {
    let physicalState: PlanetaryPhysicalState
    let liquidWaterCoverage: Double
    let waterIceCoverage: Double
    let diameter: CGFloat

    private var primaryColor: Color {
        switch physicalState.bulk {
        case .metalRich: .gray
        case .rocky: .orange
        case .volatileRich: .teal
        case .hydrogenHeliumDominated: .purple
        }
    }

    private var secondaryColor: Color {
        switch physicalState.thermal {
        case .frozen: .white
        case .temperate: .green
        case .hot: .red
        case .molten: .yellow
        }
    }

    private var atmosphereColor: Color {
        switch physicalState.atmosphere {
        case .airless: .clear
        case .tenuous: .cyan.opacity(0.35)
        case .secondary: .cyan.opacity(0.6)
        case .deepEnvelope: .indigo.opacity(0.75)
        }
    }

    private var accessibleWaterCoverage: Double {
        min(1, max(0, liquidWaterCoverage + waterIceCoverage))
    }

    private var atmosphereLineWidth: Double {
        max(0.75, diameter * 0.11)
    }

    private var waterLineWidth: Double {
        max(0.75, min(2.2, diameter * 0.12))
    }

    var body: some View {
        ZStack {
            if physicalState.atmosphere != .airless {
                Circle()
                    .stroke(atmosphereColor, lineWidth: atmosphereLineWidth)
                    .blur(radius: diameter * 0.05)
                    .padding(diameter * 0.05)
            }

            Circle()
                .fill(
                    RadialGradient(
                        colors: [.white.opacity(0.82), secondaryColor, primaryColor.opacity(0.88)],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: diameter * 0.72
                    )
                )
                .overlay {
                    Circle()
                        .stroke(.white.opacity(0.35), lineWidth: 0.7)
                }

            if accessibleWaterCoverage > 0 {
                Circle()
                    .trim(from: 0, to: accessibleWaterCoverage)
                    .stroke(.blue.opacity(0.9), style: StrokeStyle(lineWidth: waterLineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .padding(1.5)
            }
        }
        .frame(width: diameter, height: diameter)
        .shadow(color: primaryColor.opacity(0.5), radius: diameter * 0.2)
    }
}
