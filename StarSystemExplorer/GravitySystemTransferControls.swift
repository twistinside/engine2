import SwiftUI

/// Selects a circular-reference transfer pair and exposes its reference epochs.
struct GravitySystemTransferControls: View {
    let model: GravitySystemExplorerModel
    @Binding var playback: GravitySystemPlayback

    private let presentation = GravitySystemPresentation()

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

    @ViewBuilder private var planetPairControls: some View {
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
    }

    @ViewBuilder private var referenceEpochControls: some View {
        if let plan = model.transferPlan {
            HStack {
                Button("Show reference epoch") {
                    setDisplayedEpoch(0, at: Date())
                }
                .buttonStyle(.bordered)

                Button("Show departure") {
                    setDisplayedEpoch(
                        plan.departureEpoch.secondsSinceReferenceEpoch,
                        at: Date()
                    )
                }
                .buttonStyle(.borderedProminent)

                Spacer()

                Text(
                    "Wait from planning epoch "
                        + presentation.epoch(plan.planningEpoch)
                        + ": "
                        + presentation.elapsedTime(seconds: plan.nextWindowWait.seconds)
                )
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            planetPairControls
            referenceEpochControls
        }
    }

    private func setDisplayedEpoch(_ elapsedSeconds: Double, at date: Date) {
        model.setElapsedSeconds(elapsedSeconds)
        playback.synchronize(
            to: model.elapsedSeconds,
            at: date,
            upperBound: model.maximumElapsedSeconds
        )
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
