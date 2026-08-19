import simd

/// Sums Newtonian acceleration from the star and generated rail bodies.
///
/// The field evaluates sources through ``GravitySystemEphemeris`` and follows
/// its stable body order. A caller may exclude its own generated identity.
/// Queries at or inside a source's physical radius are rejected instead of
/// softening or dividing by a singular distance.
nonisolated struct PlanarGravityField: Sendable {
    let ephemeris: GravitySystemEphemeris

    /// Returns total acceleration at one position and celestial epoch.
    func acceleration(
        at position: PlanarPosition,
        epoch: CelestialEpoch,
        excluding excludedBodyID: GeneratedBodyID? = nil
    ) throws(PlanarGravityFieldError) -> PlanarAcceleration {
        try acceleration(
            at: position,
            fromExactStates: ephemeris.states(at: epoch),
            excluding: excludedBodyID
        )
    }

    /// Returns total acceleration from one complete, stable-order ephemeris evaluation.
    ///
    /// Callers use this overload when they already own the exact states produced
    /// by this field's ephemeris for the requested epoch.
    func acceleration(
        at position: PlanarPosition,
        fromExactStates bodyStates: [GravityBodyState],
        excluding excludedBodyID: GeneratedBodyID? = nil
    ) throws(PlanarGravityFieldError) -> PlanarAcceleration {
        var acceleration = SIMD2<Double>.zero

        let starOffset = -position.meters
        let starDistanceSquared = simd_length_squared(starOffset)
        guard starDistanceSquared > ephemeris.system.starRadius.meters
            * ephemeris.system.starRadius.meters else {
            throw .contactWithStar
        }
        let starParameter = GravitationalParameter(
            primaryMass: ephemeris.system.starMass,
            orbitingMass: .zero
        ).cubicMetersPerSecondSquared
        acceleration += starOffset * starParameter
            / (starDistanceSquared * starDistanceSquared.squareRoot())

        for bodyState in bodyStates {
            let body = bodyState.body
            guard body.id != excludedBodyID else {
                continue
            }
            let offset = bodyState.state.position.meters - position.meters
            let distanceSquared = simd_length_squared(offset)
            guard distanceSquared > body.radius.meters * body.radius.meters else {
                throw .contactWithBody(body.id)
            }
            let bodyParameter = GravitationalParameter(
                primaryMass: body.mass,
                orbitingMass: .zero
            ).cubicMetersPerSecondSquared
            acceleration += offset * bodyParameter
                / (distanceSquared * distanceSquared.squareRoot())
        }

        guard acceleration.isFinite else {
            throw .nonfiniteAcceleration
        }
        return PlanarAcceleration(metersPerSecondSquared: acceleration)
    }
}
