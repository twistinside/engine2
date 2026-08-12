import SwiftUI

/// Edits a caller-selected seed, chooses system-random seeds, and starts generation.
struct StarSystemSeedControls: View {
    @Bindable var model: StarSystemExplorerModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("STAR SYSTEM EXPLORER")
                        .font(.caption.weight(.bold))
                        .tracking(2.2)
                        .foregroundStyle(.cyan)
                    Text("Procedural observatory")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 5) {
                    HStack(spacing: 8) {
                        TextField("Seed", text: $model.seedText)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                            .frame(width: 260)
                            .help("Enter an unsigned 64-bit decimal or 0x-prefixed hexadecimal seed")
                            .disabled(model.isGenerating)
                            .onSubmit {
                                model.generate()
                            }

                        Button("Random", systemImage: "dice.fill") {
                            model.chooseRandomSeed()
                        }
                        .buttonStyle(.bordered)
                        .help("Choose a random seed and generate its star system")
                        .disabled(model.isGenerating)

                        Button("Generate", systemImage: "sparkles") {
                            model.generate()
                        }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                        .disabled(model.isGenerating)

                        if model.isGenerating {
                            ProgressView()
                                .controlSize(.small)
                                .accessibilityLabel("Generating star system")
                        }
                    }

                    Text("UInt64 seed: decimal or 0x hex; underscores allowed.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: 590, alignment: .trailing)
            }

            if let errorMessage = model.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.orange)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(.white.opacity(0.1))
                .frame(height: 1)
        }
    }
}
