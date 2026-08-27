/// Fixed dry mass whose live value also includes stored fuel and cargo.
struct CMass: PComponent {
    let dryMass: Double

    init(dryMass: Double) {
        precondition(dryMass.isFinite && dryMass > 0, "Dry mass must be finite and positive.")
        self.dryMass = dryMass
    }
}
