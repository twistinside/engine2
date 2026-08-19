import SwiftUI

/// Edits the displayed epoch and circular-reference transfer pair without mutating generated gravity facts.
struct GravitySystemControls: View {
    @Bindable var model: GravitySystemExplorerModel

    private let presentation = GravitySystemPresentation()

    private var elapsedTimeBinding: Binding<Double> {
        Binding(
            get: { model.elapsedSeconds },
            set: { model.setElapsedSeconds($0) }
        )
    }

    private var sourceSelection: Binding<GeneratedBodyID?> {
        Binding(
            get: { model.selectedSourceID },
            set: { bodyID in
                if let bodyID {
                    model.selectSource(bodyID)
                }
            }
        )
    }

    private var destinationSelection: Binding<GeneratedBodyID?> {
        Binding(
            get: { model.selectedDestinationID },
            set: { bodyID in
                if let bodyID {
                    model.selectDestination(bodyID)
                }
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Displayed epoch", systemImage: "clock.arrow.circlepath")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(presentation.elapsedTime(seconds: model.elapsedSeconds))
                        .font(.system(.body, design: .monospaced, weight: .semibold))
                }

                Slider(
                    value: elapsedTimeBinding,
                    in: 0...max(model.maximumElapsedSeconds, 1)
                )
                .help("Scrub deterministic rail ephemerides without advancing Simulation")

                HStack {
                    Text("Reference epoch")
                    Spacer()
                    Text(presentation.elapsedTime(seconds: model.maximumElapsedSeconds))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Divider()

            if model.sourceSystem.planets.count >= 2 {
                HStack(alignment: .bottom, spacing: 12) {
                    planetPicker(
                        title: "Departure planet",
                        selection: sourceSelection,
                        planets: model.sourceSystem.planets
                    )

                    Button("Swap", systemImage: "arrow.left.arrow.right") {
                        model.swapSelectedPlanets()
                    }
                    .buttonStyle(.bordered)

                    planetPicker(
                        title: "Destination planet",
                        selection: destinationSelection,
                        planets: model.sourceSystem.planets.filter { $0.id != model.selectedSourceID }
                    )
                }
            } else {
                Label(
                    model.sourceSystem.planets.isEmpty
                        ? "This valid system has no resolved planets to connect."
                        : "A transfer comparison requires a second resolved planet.",
                    systemImage: "point.2.filled.connected.trianglepath.dotted"
                )
                .font(.callout)
                .foregroundStyle(.secondary)
            }

            if let plan = model.transferPlan {
                HStack {
                    Button("Reference epoch") {
                        model.setElapsedSeconds(0)
                    }
                    .buttonStyle(.bordered)

                    Button("Show departure") {
                        model.setElapsedSeconds(plan.departureEpoch.secondsSinceReferenceEpoch)
                    }
                    .buttonStyle(.borderedProminent)

                    Spacer()

                    Text(
                        "Reference departure window: "
                            + presentation.elapsedTime(seconds: plan.nextWindowWait.seconds)
                    )
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func planetPicker(
        title: String,
        selection: Binding<GeneratedBodyID?>,
        planets: [GeneratedPlanet]
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .tracking(0.7)
                .foregroundStyle(.secondary)
            Picker(title, selection: selection) {
                ForEach(planets, id: \.id) { planet in
                    Text(
                        "\(model.planetLabel(for: planet.id)) · "
                            + presentation.distance(planet.orbit.semiMajorAxis)
                    )
                    .tag(Optional(planet.id))
                }
            }
            .labelsHidden()
            .frame(maxWidth: .infinity)
        }
    }
}
