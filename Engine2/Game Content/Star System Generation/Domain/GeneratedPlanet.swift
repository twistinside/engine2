/// Immutable present-day planet and its resolved satellite system.
///
/// Composition follows accreted material through migration and mergers. The
/// derived environment and classifications describe the current orbit; they do
/// not rewrite where that material formed.
nonisolated struct GeneratedPlanet: Codable, Equatable, Sendable {
    let id: GeneratedBodyID
    let composition: CelestialMassComposition
    let radius: AstronomicalDistance
    let orbit: KeplerianOrbit
    let environment: PlanetaryEnvironment
    let physicalState: PlanetaryPhysicalState
    let moons: [GeneratedMoon]
    let progenitorCount: Int

    var mass: AstronomicalMass {
        composition.totalMass
    }

    func orbitalClearance(
        to outer: GeneratedPlanet,
        around centralMass: AstronomicalMass
    ) -> OrbitalPairClearance {
        OrbitalPairClearance(
            innerMass: mass,
            outerMass: outer.mass,
            centralMass: centralMass,
            innerSemimajorAxis: orbit.semiMajorAxis.astronomicalUnits,
            outerSemimajorAxis: outer.orbit.semiMajorAxis.astronomicalUnits,
            innerEccentricity: orbit.eccentricity.rawValue,
            outerEccentricity: outer.orbit.eccentricity.rawValue
        )
    }
}
