import SwiftUI

/// Arranges the complete generated result into overview, formation, body, and provenance sections.
struct GeneratedStarSystemDashboard: View {
    let system: GeneratedStarSystem

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                StarSystemOverview(system: system)
                StarSystemOrbitDiagram(system: system)

                LazyVGrid(
                    columns: [
                        GridItem(.adaptive(minimum: 470), spacing: 18, alignment: .topLeading)
                    ],
                    alignment: .leading,
                    spacing: 18
                ) {
                    GeneratedStarCard(star: system.star)
                    ProtoplanetaryDiskCard(disk: system.protoplanetaryDisk)
                }

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
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 520), spacing: 18)], alignment: .leading, spacing: 18
                    ) {
                        ForEach(Array(system.planets.enumerated()), id: \.element.id) { index, planet in
                            GeneratedPlanetCard(planet: planet, ordinal: index + 1)
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
