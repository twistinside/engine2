import simd

/// Thrust and exhaust limits for one propulsion system.
struct PropulsionComponent: Component {
    /// Finite acceleration and propellant use admitted for one fixed interval.
    struct Burn: Equatable {
        let acceleration: SIMD3<Double>
        let fuelUsed: Double
    }

    let exhaustVelocity: Double
    let maximumThrust: Double

    init(maximumThrust: Double, exhaustVelocity: Double) {
        precondition(maximumThrust.isFinite && maximumThrust > 0, "Maximum thrust must be finite and positive.")
        precondition(exhaustVelocity.isFinite && exhaustVelocity > 0, "Exhaust velocity must be finite and positive.")
        self.maximumThrust = maximumThrust
        self.exhaustVelocity = exhaustVelocity
    }

    /// Limits one requested velocity change by thrust, live mass, fuel, and interval duration.
    func burn(
        toward requestedVelocityChange: SIMD3<Double>,
        mass: Double,
        availableFuel: Double,
        deltaTime: Double
    ) -> Burn? {
        let requestedDeltaV = simd_length(requestedVelocityChange)
        guard requestedVelocityChange.isFinite,
              requestedDeltaV.isFinite,
              requestedDeltaV > 0,
              mass.isFinite,
              mass > 0,
              availableFuel.isFinite,
              availableFuel > 0,
              deltaTime.isFinite,
              deltaTime > 0 else {
            return nil
        }

        let requestedForceMagnitude = requestedDeltaV / deltaTime * mass
        let admittedForce = min(requestedForceMagnitude, maximumThrust)
        let admittedImpulse = min(
            admittedForce * deltaTime,
            availableFuel * exhaustVelocity
        )
        guard admittedImpulse.isFinite, admittedImpulse > 0 else {
            return nil
        }

        let direction = requestedVelocityChange / requestedDeltaV
        return Burn(
            acceleration: direction * (admittedImpulse / deltaTime / mass),
            fuelUsed: admittedImpulse / exhaustVelocity
        )
    }
}

extension PropulsionComponent {
    @MainActor init?(for entity: Entity, from state: Entity.InitialState) {
        let isPropelled = entity is Propelled
        precondition(
            (state.maximumThrust != nil) == isPropelled &&
                (state.exhaustVelocity != nil) == isPropelled,
            "Propelled requires maximum thrust and exhaust velocity; other entities must omit both."
        )
        guard let maximumThrust = state.maximumThrust, let exhaustVelocity = state.exhaustVelocity else {
            return nil
        }
        self.init(maximumThrust: maximumThrust, exhaustVelocity: exhaustVelocity)
    }
}
