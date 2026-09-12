/// Marks an entity for structural removal at the end of the current Simulation tick.
///
/// The entity and its component rows remain available for effects processing until collection.
/// Later gameplay systems must exclude marked entities from active participation.
struct PendingRemovalComponent: Component {}
