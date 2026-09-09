/// Remaining simulation time before an entity expires, independent of its other capabilities.
struct LifetimeComponent: Component {
    var remainingLifetime: Double

    init(remainingLifetime: Double) {
        precondition(
            remainingLifetime.isFinite && remainingLifetime > 0,
            "Remaining lifetime must be finite and positive."
        )
        self.remainingLifetime = remainingLifetime
    }
}
