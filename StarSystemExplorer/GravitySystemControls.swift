import SwiftUI

/// Plays or edits the displayed epoch and circular-reference transfer pair without mutating generated gravity facts.
struct GravitySystemControls: View {
    @Bindable var model: GravitySystemExplorerModel

    @State private var playback = GravitySystemPlayback()

    private let presentation = GravitySystemPresentation()

    private var elapsedTimeBinding: Binding<Double> {
        Binding(
            get: { model.elapsedSeconds },
            set: { setDisplayedEpoch($0, at: Date()) }
        )
    }

    private var playbackRateBinding: Binding<GravitySystemPlaybackRate> {
        Binding(
            get: { playback.rate },
            set: { rate in
                playback.selectRate(
                    rate,
                    from: model.elapsedSeconds,
                    at: Date(),
                    upperBound: model.maximumElapsedSeconds
                )
            }
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
        TimelineView(
            .animation(
                minimumInterval: GravitySystemPlayback.preferredFrameIntervalSeconds,
                paused: !playback.isPlaying
            )
        ) { context in
            controlsContent
                .onChange(of: context.date) { _, date in
                    advancePlayback(to: date)
                }
        }
    }

    private var controlsContent: some View {
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
                ) {
                    Text("Displayed epoch")
                }
                .labelsHidden()
                .accessibilityValue(
                    presentation.elapsedTime(seconds: model.elapsedSeconds)
                )
                .help("Scrub deterministic rail ephemerides without advancing Simulation")

                HStack(spacing: 10) {
                    Button(
                        playback.isPlaying ? "Pause" : "Play",
                        systemImage: playback.isPlaying ? "pause.fill" : "play.fill"
                    ) {
                        togglePlayback(at: Date())
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(
                        !playback.isPlaying
                            && model.elapsedSeconds >= model.maximumElapsedSeconds
                    )
                    .help(
                        playback.isPlaying
                            ? "Pause displayed epoch playback"
                            : "Animate the displayed ephemeris without advancing Simulation"
                    )

                    Picker("Playback rate", selection: playbackRateBinding) {
                        ForEach(GravitySystemPlaybackRate.allCases) { rate in
                            Text(rate.title).tag(rate)
                        }
                    }
                    .pickerStyle(.menu)
                    .fixedSize()
                    .help("Choose displayed elapsed time per wall-clock second")

                    Spacer()

                    Text("Display-only rail playback")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

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
                        "Reference departure window: "
                            + presentation.elapsedTime(seconds: plan.nextWindowWait.seconds)
                    )
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func advancePlayback(to date: Date) {
        guard let elapsedSeconds = playback.advance(
            to: date,
            upperBound: model.maximumElapsedSeconds
        ) else {
            return
        }
        model.setElapsedSeconds(elapsedSeconds)
    }

    private func togglePlayback(at date: Date) {
        if playback.isPlaying {
            model.setElapsedSeconds(
                playback.pause(
                    at: date,
                    upperBound: model.maximumElapsedSeconds
                )
            )
        } else {
            playback.start(
                from: model.elapsedSeconds,
                at: date,
                upperBound: model.maximumElapsedSeconds
            )
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
