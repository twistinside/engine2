/// Authored circular rail around a live primary. World derives placement and velocity at elapsed time zero.
struct OrbitalRailInitialState {
    let primaryEntityID: EntityID
    let radius: Double
    let angularSpeed: Double
    let phase: Double
}
