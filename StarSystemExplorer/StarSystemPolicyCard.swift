import SwiftUI

/// Exposes the complete persisted calibration so a generated system remains auditable in the UI.
struct StarSystemPolicyCard: View {
    let policy: StarSystemGenerationPolicy

    @State private var isExpanded = false

    private let presentation = StarSystemPresentation()

    var body: some View {
        ExplorerCard(
            title: "Model Policy",
            subtitle: "Complete persisted calibration",
            systemImage: "slider.horizontal.3",
            tint: .secondary
        ) {
            DisclosureGroup(isExpanded: $isExpanded) {
                VStack(alignment: .leading, spacing: 18) {
                    policySectionTitle("Stellar population")
                    EagerAdaptiveGrid(minimumColumnWidth: 165, horizontalSpacing: 8, verticalSpacing: 8) {
                        MetricTile(
                            "Minimum stellar mass", value: "\(presentation.number(policy.minimumStellarMassSolar)) M☉")
                        MetricTile(
                            "Maximum stellar mass", value: "\(presentation.number(policy.maximumStellarMassSolar)) M☉")
                        MetricTile("Metallicity mean", value: "\(presentation.number(policy.metallicityMeanDex)) dex")
                        MetricTile(
                            "Metallicity deviation",
                            value: "\(presentation.number(policy.metallicityStandardDeviationDex)) dex")
                        MetricTile(
                            "Metallicity minimum", value: "\(presentation.number(policy.minimumMetallicityDex)) dex")
                        MetricTile(
                            "Metallicity maximum", value: "\(presentation.number(policy.maximumMetallicityDex)) dex")
                        MetricTile("Minimum age", value: "\(presentation.number(policy.minimumSystemAgeGigayears)) Gyr")
                        MetricTile("Maximum age", value: "\(presentation.number(policy.maximumSystemAgeGigayears)) Gyr")
                    }

                    policySectionTitle("Disk population")
                    EagerAdaptiveGrid(minimumColumnWidth: 165, horizontalSpacing: 8, verticalSpacing: 8) {
                        MetricTile("Median disk ratio", value: presentation.number(policy.medianDiskMassRatio))
                        MetricTile("Disk scatter", value: "\(presentation.number(policy.diskMassScatterDex)) dex")
                        MetricTile("Minimum disk ratio", value: presentation.number(policy.minimumDiskMassRatio))
                        MetricTile("Maximum disk ratio", value: presentation.number(policy.maximumDiskMassRatio))
                        MetricTile(
                            "Median lifetime", value: "\(presentation.number(policy.medianDiskLifetimeMegayears)) Myr")
                        MetricTile(
                            "Lifetime scatter", value: "\(presentation.number(policy.diskLifetimeScatterDex)) dex")
                        MetricTile(
                            "Minimum lifetime", value: "\(presentation.number(policy.minimumDiskLifetimeMegayears)) Myr"
                        )
                        MetricTile(
                            "Maximum lifetime", value: "\(presentation.number(policy.maximumDiskLifetimeMegayears)) Myr"
                        )
                        MetricTile(
                            "Median characteristic radius",
                            value: "\(presentation.number(policy.medianCharacteristicRadiusAU)) AU")
                        MetricTile(
                            "Radius scatter", value: "\(presentation.number(policy.characteristicRadiusScatterDex)) dex"
                        )
                        MetricTile("Base solid fraction", value: presentation.percent(policy.baseSolidFraction))
                        MetricTile("Annuli", value: String(policy.annulusCount))
                    }

                    policySectionTitle("Bounded formation work")
                    EagerAdaptiveGrid(minimumColumnWidth: 165, horizontalSpacing: 8, verticalSpacing: 8) {
                        MetricTile("Maximum embryos", value: String(policy.maximumEmbryoCount))
                        MetricTile("Formation steps", value: String(policy.formationStepCount))
                        MetricTile("Evolution steps", value: String(policy.evolutionStepCount))
                        MetricTile("Post-disk encounters", value: String(policy.maximumPostDiskEncounterCount))
                        MetricTile("Embryo seed mass", value: "\(presentation.number(policy.embryoSeedMassEarth)) M⊕")
                        MetricTile(
                            "Resolved solid threshold",
                            value: "\(presentation.number(policy.minimumResolvedPlanetSolidMassEarth)) M⊕")
                        MetricTile("Maximum resolved planets", value: String(policy.maximumResolvedPlanetCount))
                    }

                    policySectionTitle("Accretion and architecture")
                    EagerAdaptiveGrid(minimumColumnWidth: 165, horizontalSpacing: 8, verticalSpacing: 8) {
                        MetricTile("Solid efficiency", value: presentation.percent(policy.solidAccretionEfficiency))
                        MetricTile("Gas efficiency", value: presentation.percent(policy.gasAccretionEfficiency))
                        MetricTile("Migration efficiency", value: presentation.percent(policy.migrationEfficiency))
                        MetricTile(
                            "Formation merger spacing", value: presentation.number(policy.formationMergerSpacing))
                        MetricTile(
                            "Radial clearance",
                            value: "\(presentation.number(policy.radialClearanceHillRadii)) Hill radii")
                        MetricTile("Final planet spacing", value: presentation.number(policy.finalPlanetSpacing))
                        MetricTile("Final giant spacing", value: presentation.number(policy.finalGiantPlanetSpacing))
                        MetricTile(
                            "Giant threshold", value: "\(presentation.number(policy.giantMassThresholdEarth)) M⊕")
                    }

                    policySectionTitle("Atmospheres and moons")
                    EagerAdaptiveGrid(minimumColumnWidth: 165, horizontalSpacing: 8, verticalSpacing: 8) {
                        MetricTile("Escape efficiency", value: presentation.percent(policy.atmosphereEscapeEfficiency))
                        MetricTile("Maximum moons", value: String(policy.maximumMoonCountPerPlanet))
                    }
                }
                .padding(.top, 14)
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(presentation.label(for: policy.modelVersion))
                            .font(.subheadline.weight(.semibold))
                        Text(
                            policy.isSupportedCalibration
                                ? "Canonical supported calibration" : "Unsupported calibration"
                        )
                        .font(.caption)
                        .foregroundStyle(policy.isSupportedCalibration ? .green : .orange)
                    }
                    Spacer()
                    Text(isExpanded ? "Hide calibration" : "Show calibration")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func policySectionTitle(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.caption2.weight(.bold))
            .tracking(1)
            .foregroundStyle(.secondary)
    }
}
