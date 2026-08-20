/// Detached input for one body in a planar orbital-dynamics step.
///
/// The stepper validates SI mass, radius, state, identity order, and gravity
/// participation before calculation. It never retains this value or mutates the
/// caller's array.
nonisolated struct PlanarOrbitalBody: Equatable, Sendable {
    let id: CelestialBodyID
    let massKilograms: Double
    let radiusMeters: Double
    let initialState: PlanarStateVector
    let propagation: PlanarOrbitalPropagation
    let gravityParticipation: GravityParticipation
}
