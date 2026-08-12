import SwiftUI

/// Visualizes every conserved composition reservoir in Earth-mass units.
struct CelestialCompositionView: View {
    let title: String
    let composition: CelestialMassComposition

    private let presentation = StarSystemPresentation()
    private let labels = ["Iron", "Silicate", "Water", "Other volatiles", "Hydrogen / helium"]
    private let colors: [Color] = [.red, .orange, .blue, .teal, .purple]

    private var masses: [Double] {
        [
            composition.iron.earthMasses,
            composition.silicate.earthMasses,
            composition.water.earthMasses,
            composition.otherVolatiles.earthMasses,
            composition.hydrogenHelium.earthMasses,
        ]
    }

    private var totalMass: Double {
        masses.reduce(0, +)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(presentation.earthMasses(composition.totalMass))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Canvas { context, size in
                guard totalMass > 0 else {
                    context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.gray.opacity(0.25)))
                    return
                }

                var originX = 0.0
                for index in masses.indices {
                    let width = size.width * masses[index] / totalMass
                    let segment = CGRect(x: originX, y: 0, width: width, height: size.height)
                    context.fill(Path(segment), with: .color(colors[index]))
                    originX += width
                }
            }
            .frame(height: 12)
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(.white.opacity(0.16), lineWidth: 1)
            }

            EagerAdaptiveGrid(minimumColumnWidth: 140, horizontalSpacing: 8, verticalSpacing: 6) {
                ForEach(masses.indices, id: \.self) { index in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(colors[index])
                            .frame(width: 7, height: 7)
                        Text(labels[index])
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 2)
                        Text(presentation.number(masses[index]))
                            .font(.caption2.monospacedDigit())
                    }
                }
            }
        }
    }
}
