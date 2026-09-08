/// Authored projectile owner and flight duration. World creates the remaining-lifetime state.
struct MissileInitialState {
    let ownerEntityID: EntityID
    let lifetime: Double
}
