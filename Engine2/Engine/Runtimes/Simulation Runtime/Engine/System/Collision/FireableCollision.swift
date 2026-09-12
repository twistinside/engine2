/// Immutable earliest-contact fact captured for one fired body during the current Simulation tick.
///
/// The World retains these facts until final entity collection. They are local system input, not
/// an event journal. The fraction measures elapsed time against the complete tick, even when a
/// participant's remaining lifetime shortened the sweep.
struct FireableCollision {
    let entityID: EntityID
    let targetEntityID: EntityID
    let tickFraction: Double
}
