/// Finite mineable ore remaining in one resource body.
struct COreDeposit: PComponent {
    var remainingOre: Double

    init(remainingOre: Double) {
        precondition(remainingOre.isFinite && remainingOre >= 0, "Remaining ore must be finite and nonnegative.")
        self.remainingOre = remainingOre
    }
}
