/// Simulation-owned projectile lifetime and the complete identity excluded from its impacts.
struct MissileComponent: Component {
    let ownerEntityID: EntityID
    var remainingLifetime: Double

    init(ownerEntityID: EntityID, remainingLifetime: Double) {
        precondition(
            remainingLifetime.isFinite && remainingLifetime > 0,
            "Missile lifetime must be finite and positive."
        )
        self.ownerEntityID = ownerEntityID
        self.remainingLifetime = remainingLifetime
    }
}
