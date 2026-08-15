/// Immutable present-day moon produced from a regular disk or recorded giant impact.
///
/// Stable-orbit bounds retain the Roche and eccentric Hill limits used during
/// construction so persistence validation can replay the satellite architecture.
nonisolated struct GeneratedMoon: Codable, Equatable, Sendable {
    let id: GeneratedBodyID
    let origin: MoonFormationOrigin
    let composition: CelestialMassComposition
    let radius: AstronomicalDistance
    let orbit: KeplerianOrbit
    let minimumStableOrbit: AstronomicalDistance
    let maximumStableOrbit: AstronomicalDistance
    let environment: PlanetaryEnvironment
    let physicalState: PlanetaryPhysicalState

    var mass: AstronomicalMass {
        composition.totalMass
    }

    func orbitalClearance(
        to outer: GeneratedMoon,
        around centralMass: AstronomicalMass
    ) -> OrbitalPairClearance {
        OrbitalPairClearance(
            innerMass: mass,
            outerMass: outer.mass,
            centralMass: centralMass,
            innerSemimajorAxis: orbit.semiMajorAxis.meters,
            outerSemimajorAxis: outer.orbit.semiMajorAxis.meters,
            innerEccentricity: orbit.eccentricity.rawValue,
            outerEccentricity: outer.orbit.eccentricity.rawValue
        )
    }
}
