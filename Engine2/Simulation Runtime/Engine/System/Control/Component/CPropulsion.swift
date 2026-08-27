/// Thrust and exhaust limits for one propulsion system.
struct CPropulsion: PComponent {
    let exhaustVelocity: Double
    let maximumThrust: Double

    init(maximumThrust: Double, exhaustVelocity: Double) {
        precondition(maximumThrust.isFinite && maximumThrust > 0, "Maximum thrust must be finite and positive.")
        precondition(exhaustVelocity.isFinite && exhaustVelocity > 0, "Exhaust velocity must be finite and positive.")
        self.maximumThrust = maximumThrust
        self.exhaustVelocity = exhaustVelocity
    }
}
