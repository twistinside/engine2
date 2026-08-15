import SwiftUI

/// Presents seed controls and the complete visual dashboard for the latest successful generation.
struct StarSystemExplorerView: View {
    @State private var model: StarSystemExplorerModel

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.025, green: 0.035, blue: 0.075),
                    Color(red: 0.055, green: 0.035, blue: 0.105),
                    Color(red: 0.018, green: 0.055, blue: 0.075),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                StarSystemSeedControls(model: model)

                Group {
                    if let system = model.system {
                        GeneratedStarSystemDashboard(system: system)
                    } else {
                        ContentUnavailableView {
                            Label("No System Yet", systemImage: "sparkles")
                        } description: {
                            Text("Enter a seed to generate a deterministic star, disk, planets, and moons.")
                        } actions: {
                            if model.isGenerating {
                                ProgressView("Forming system…")
                            } else {
                                Button("Generate") {
                                    model.generate()
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 960, minHeight: 680)
        .preferredColorScheme(.dark)
        .task {
            model.generateIfNeeded()
        }
    }

    init(model: StarSystemExplorerModel = StarSystemExplorerModel()) {
        _model = State(initialValue: model)
    }
}

#Preview("Seed 1") {
    let seed = StarSystemSeed(rawValue: 1)
    let system = try? StarSystemGenerator(policy: .coreAccretionLiteV1).generate(seed: seed)
    StarSystemExplorerView(
        model: StarSystemExplorerModel(seedText: String(seed.rawValue), system: system)
    )
    .frame(width: 1_280, height: 900)
}

#Preview("Seed 43 · No Planets") {
    let seed = StarSystemSeed(rawValue: 43)
    let system = try? StarSystemGenerator(policy: .coreAccretionLiteV1).generate(seed: seed)
    StarSystemExplorerView(
        model: StarSystemExplorerModel(seedText: String(seed.rawValue), system: system)
    )
    .frame(width: 1_280, height: 900)
}
