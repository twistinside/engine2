import SwiftUI

/// Plays or scrubs one bounded displayed epoch without advancing Simulation.
struct GravitySystemEpochControls: View {
    let model: GravitySystemExplorerModel
    @Binding var playback: GravitySystemPlayback

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

    private var playbackButtons: some View {
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
    }

    var body: some View {
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

            playbackButtons

            HStack {
                Text("Timeline end")
                Spacer()
                Text(presentation.elapsedTime(seconds: model.maximumElapsedSeconds))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .background {
            GravitySystemPlaybackTimelineDriver(isPlaying: playback.isPlaying) { date in
                advancePlayback(to: date)
            }
        }
    }

    private func advancePlayback(to date: Date) {
        var projectedPlayback = playback
        guard let elapsedSeconds = projectedPlayback.advance(
            to: date,
            upperBound: model.maximumElapsedSeconds
        ) else {
            return
        }
        if projectedPlayback.isPlaying != playback.isPlaying {
            playback = projectedPlayback
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
}
