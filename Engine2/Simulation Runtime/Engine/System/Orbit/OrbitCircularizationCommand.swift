/// One interval-local request to circularize an entity around its designated primary.
nonisolated struct OrbitCircularizationCommand: Equatable, Sendable {
    let entityID: EntityID
}
