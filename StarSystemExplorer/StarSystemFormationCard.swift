import SwiftUI

/// Visualizes the complete conserved mass destinations, ancestry, and bounded encounter history.
struct StarSystemFormationCard: View {
    let ledger: StarSystemFormationLedger

    @State private var showsMaterialDestinations = false

    private var solidBudgetValues: [Double] {
        [
            ledger.retainedSolidMass.earthMasses,
            ledger.unaccretedSolidMass.earthMasses,
            ledger.residualBodyComposition.solidMass.earthMasses,
            ledger.dynamicalLosses.ejectedComposition.solidMass.earthMasses,
            ledger.dynamicalLosses.starAccretedComposition.solidMass.earthMasses,
            ledger.dynamicalLosses.collisionDebrisComposition.solidMass.earthMasses,
        ]
    }

    private var gasBudgetValues: [Double] {
        [
            ledger.retainedHydrogenHeliumMass.earthMasses,
            ledger.escapedHydrogenHeliumMass.earthMasses,
            ledger.dispersedGasMass.earthMasses,
            ledger.residualBodyComposition.hydrogenHelium.earthMasses,
            ledger.dynamicalLosses.ejectedComposition.hydrogenHelium.earthMasses,
            ledger.dynamicalLosses.starAccretedComposition.hydrogenHelium.earthMasses,
            ledger.dynamicalLosses.collisionDebrisComposition.hydrogenHelium.earthMasses,
        ]
    }

    var body: some View {
        ExplorerCard(
            title: "Formation Ledger",
            subtitle: "Conserved reservoirs and bounded dynamical history",
            systemImage: "point.3.filled.connected.trianglepath.dotted",
            tint: .green
        ) {
            LedgerBudgetBar(
                title: "Solid mass · initial \(StarSystemPresentation().earthMasses(ledger.initialSolidMass))",
                values: solidBudgetValues,
                labels: [
                    "Retained bodies", "Unaccreted disk", "Residual bodies", "Ejected", "Star accreted",
                    "Collision debris",
                ],
                colors: [.green, .teal, .secondary, .red, .orange, .yellow]
            )

            LedgerBudgetBar(
                title: "Hydrogen / helium · initial \(StarSystemPresentation().earthMasses(ledger.initialGasMass))",
                values: gasBudgetValues,
                labels: [
                    "Retained envelopes", "Escaped atmosphere", "Dispersed disk", "Residual bodies", "Ejected",
                    "Star accreted", "Collision debris",
                ],
                colors: [.purple, .cyan, .indigo, .secondary, .red, .orange, .yellow]
            )

            EagerAdaptiveGrid(minimumColumnWidth: 150, horizontalSpacing: 8, verticalSpacing: 8) {
                MetricTile(
                    "Seeded embryos", value: String(ledger.seededEmbryoCount), systemImage: "circle.grid.3x3.fill",
                    tint: .teal)
                MetricTile(
                    "Formation mergers", value: String(ledger.formationMergerCount),
                    systemImage: "arrow.triangle.merge", tint: .orange)
                MetricTile(
                    "Post-disk mergers", value: String(ledger.postDiskCollisionMergerCount), systemImage: "burst.fill",
                    tint: .red)
                MetricTile(
                    "Scatterings", value: String(ledger.dynamicalLosses.scatteringCount),
                    systemImage: "arrow.triangle.branch", tint: .purple)
                MetricTile(
                    "Ejected bodies", value: String(ledger.dynamicalLosses.ejectedBodyCount),
                    detail: "\(ledger.dynamicalLosses.ejectedProgenitorCount) progenitors",
                    systemImage: "arrow.up.forward", tint: .red)
                MetricTile(
                    "Star accretions", value: String(ledger.dynamicalLosses.starAccretedBodyCount),
                    detail: "\(ledger.dynamicalLosses.starAccretedProgenitorCount) progenitors",
                    systemImage: "sun.max.trianglebadge.exclamationmark.fill", tint: .orange)
                MetricTile(
                    "Residual bodies", value: String(ledger.residualBodyCount),
                    detail: "\(ledger.residualProgenitorCount) progenitors", systemImage: "circle.dotted",
                    tint: .secondary)
                MetricTile(
                    "Resolved capacity", value: String(ledger.resolvedPlanetCapacity),
                    detail: "Maximum detailed planets",
                    systemImage: "rectangle.stack.fill", tint: .cyan)
            }

            DisclosureGroup("Material destination compositions", isExpanded: $showsMaterialDestinations) {
                VStack(spacing: 14) {
                    CelestialCompositionView(title: "Unaccreted solids", composition: ledger.unaccretedSolidComposition)
                    CelestialCompositionView(title: "Residual bodies", composition: ledger.residualBodyComposition)
                    CelestialCompositionView(
                        title: "Ejected material", composition: ledger.dynamicalLosses.ejectedComposition)
                    CelestialCompositionView(
                        title: "Star-accreted material", composition: ledger.dynamicalLosses.starAccretedComposition)
                    CelestialCompositionView(
                        title: "Collision debris", composition: ledger.dynamicalLosses.collisionDebrisComposition)
                }
                .padding(.top, 12)
            }
            .font(.subheadline.weight(.semibold))
        }
    }
}

#Preview("Seed 1 · Formation") {
    let system = try? StarSystemGenerator(policy: .coreAccretionLiteV1).generate(
        seed: StarSystemSeed(rawValue: 1)
    )
    if let ledger = system?.formationLedger {
        ScrollView {
            StarSystemFormationCard(ledger: ledger)
                .padding()
        }
        .frame(width: 900, height: 900)
        .background(Color(red: 0.025, green: 0.035, blue: 0.075))
        .preferredColorScheme(.dark)
    }
}

#Preview("Seed 10925987079005406032 · Wide Formation") {
    let system = try? StarSystemGenerator(policy: .coreAccretionLiteV1).generate(
        seed: StarSystemSeed(rawValue: 10_925_987_079_005_406_032)
    )
    if let ledger = system?.formationLedger {
        StarSystemFormationCard(ledger: ledger)
            .padding()
            .frame(width: 1_600, height: 560)
            .background(Color(red: 0.025, green: 0.035, blue: 0.075))
            .preferredColorScheme(.dark)
    }
}
