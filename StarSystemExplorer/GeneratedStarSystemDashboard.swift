import SwiftUI

/// Arranges the complete generated result into overview, formation, body, and provenance sections.
struct GeneratedStarSystemDashboard: View {
    let system: GeneratedStarSystem

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                StarSystemOverview(system: system)
                StarSystemOrbitDiagram(system: system)

                GeneratedStarCard(star: system.star)
                    .frame(maxWidth: .infinity, alignment: .leading)
                ProtoplanetaryDiskCard(disk: system.protoplanetaryDisk)
                    .frame(maxWidth: .infinity, alignment: .leading)

                StarSystemFormationCard(ledger: system.formationLedger)

                VStack(alignment: .leading, spacing: 5) {
                    Text("RESOLVED WORLDS")
                        .font(.caption.weight(.bold))
                        .tracking(2)
                        .foregroundStyle(.orange)
                    Text("Present-day planets and parent-relative satellite systems")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)
                }
                .padding(.top, 4)

                if system.planets.isEmpty {
                    ContentUnavailableView(
                        "No Resolved Planets",
                        systemImage: "circle.slash",
                        description: Text(
                            "This valid system retains its star, disk, and complete aggregate formation ledger.")
                    )
                    .padding(40)
                    .frame(maxWidth: .infinity)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                } else {
                    VStack(spacing: 18) {
                        ForEach(Array(system.planets.enumerated()), id: \.element.id) { index, planet in
                            GeneratedPlanetCard(planet: planet, ordinal: index + 1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }

                StarSystemPolicyCard(policy: system.policy)

                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                    Text(
                        "Generator validation passed. This view displays the immutable resolved result for seed \(system.seed.rawValue)."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .padding(22)
        }
        .scrollIndicators(.visible)
    }
}

#Preview("Seed 67 · One Planet and Moon") {
    let system = try? StarSystemGenerator(policy: .coreAccretionLiteV1).generate(
        seed: StarSystemSeed(rawValue: 67)
    )
    if let system {
        GeneratedStarSystemDashboard(system: system)
            .frame(width: 1_280, height: 1_000)
            .background(Color(red: 0.025, green: 0.035, blue: 0.075))
            .preferredColorScheme(.dark)
    }
}
