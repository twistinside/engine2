/// Marks long-lived, non-entity state owned by a runtime or world.
///
/// Ownership, lifetime, and cardinality make a value a resource—not whether it
/// happens to be shared. Conforming types should remain within their owning
/// runtime's explicit boundary rather than becoming process-global services.
protocol PResource {}
