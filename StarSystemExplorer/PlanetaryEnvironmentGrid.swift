import SwiftUI

/// Presents the coarse climate and accessible-surface facts for one planet or moon.
struct PlanetaryEnvironmentGrid: View {
    let environment: PlanetaryEnvironment

    private let presentation = StarSystemPresentation()

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 135), spacing: 8)], spacing: 8) {
            MetricTile(
                "Incident flux", value: "\(presentation.number(environment.incidentFluxEarth)) S⊕",
                systemImage: "sun.rain.fill", tint: .yellow)
            MetricTile(
                "Equilibrium", value: presentation.kelvin(environment.equilibriumTemperature),
                systemImage: "thermometer.medium", tint: .orange)
            MetricTile(
                "Visible boundary", value: presentation.kelvin(environment.visibleBoundaryTemperature),
                systemImage: "thermometer.high", tint: .red)
            MetricTile(
                "Atmosphere mass", value: presentation.earthMasses(environment.atmosphereMass),
                systemImage: "aqi.medium", tint: .cyan)
            MetricTile(
                "Surface pressure", value: presentation.bars(environment.surfacePressure),
                systemImage: "gauge.with.dots.needle.50percent", tint: .purple)
            MetricTile(
                "Bond albedo", value: presentation.percent(environment.bondAlbedo),
                systemImage: "circle.lefthalf.filled", tint: .secondary)
            MetricTile(
                "Liquid water", value: presentation.percent(environment.liquidWaterCoverage), systemImage: "drop.fill",
                tint: .blue)
            MetricTile(
                "Water ice", value: presentation.percent(environment.waterIceCoverage), systemImage: "snowflake",
                tint: .cyan)
        }
    }
}
