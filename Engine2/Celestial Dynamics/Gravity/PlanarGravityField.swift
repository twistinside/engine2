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
            from: ephemeris.snapshot(at: epoch),
            excluding: excludedBodyID
        )
    }

    /// Returns total acceleration from one complete ephemeris snapshot.
    ///
    /// Callers use this overload when they already own the exact snapshot
    /// produced by this field's ephemeris. A snapshot from another generated
    /// system is rejected before any source contributes acceleration.
    func acceleration(
        at position: PlanarPosition,
        from snapshot: GravitySystemEphemerisSnapshot,
        excluding excludedBodyID: GeneratedBodyID? = nil
    ) throws(PlanarGravityFieldError) -> PlanarAcceleration {
        guard snapshot.system == ephemeris.system else {
            throw .snapshotSystemMismatch
        }

        var acceleration = try stellarAcceleration(at: position)

        for bodyState in snapshot.bodyStates {
            guard bodyState.body.id != excludedBodyID else {
                continue
            }
            acceleration += try bodyAcceleration(
                at: position,
                from: bodyState
            )
        }

        guard acceleration.isFinite else {
            throw .nonfiniteAcceleration
        }
        return PlanarAcceleration(metersPerSecondSquared: acceleration)
    }

    private func stellarAcceleration(
        at position: PlanarPosition
    ) throws(PlanarGravityFieldError) -> SIMD2<Double> {
        let offset = -position.meters
        let distanceSquared = simd_length_squared(offset)
        guard distanceSquared > ephemeris.system.starRadius.meters
            * ephemeris.system.starRadius.meters else {
            throw .contactWithStar
        }
        let parameter = GravitationalParameter(
            primaryMass: ephemeris.system.starMass,
            orbitingMass: .zero
        ).cubicMetersPerSecondSquared
        return inverseSquareAcceleration(
            offset: offset,
            distanceSquared: distanceSquared,
            parameter: parameter
        )
    }

    private func bodyAcceleration(
        at position: PlanarPosition,
        from bodyState: GravityBodyState
    ) throws(PlanarGravityFieldError) -> SIMD2<Double> {
        let body = bodyState.body
        let offset = bodyState.state.position.meters - position.meters
        let distanceSquared = simd_length_squared(offset)
        guard distanceSquared > body.radius.meters * body.radius.meters else {
            throw .contactWithBody(body.id)
        }
        let parameter = GravitationalParameter(
            primaryMass: body.mass,
            orbitingMass: .zero
        ).cubicMetersPerSecondSquared
        return inverseSquareAcceleration(
            offset: offset,
            distanceSquared: distanceSquared,
            parameter: parameter
        )
    }

    private func inverseSquareAcceleration(
        offset: SIMD2<Double>,
        distanceSquared: Double,
        parameter: Double
    ) -> SIMD2<Double> {
        offset * parameter / (distanceSquared * distanceSquared.squareRoot())
    }
}
