@testable import Engine2

/// Records component availability during the last Game Content stage before Engine collection.
final class EntityRemovalProbeSystem: System {
    let markedEntityID: EntityID
    let entityToMark: EntityID

    private(set) var observedRegisteredEntity = false
    private(set) var observedPendingRemoval = false
    private(set) var observedComponents = false
    private(set) var markedAnotherEntity = false

    init(markedEntityID: EntityID, entityToMark: EntityID) {
        self.markedEntityID = markedEntityID
        self.entityToMark = entityToMark
    }

    func update(world: inout World, deltaTime: Double) {
        observedRegisteredEntity = world.entity(for: markedEntityID) != nil
        observedPendingRemoval = world.pendingRemovalComponents[markedEntityID] != nil
        observedComponents = world.positionComponents[markedEntityID] != nil &&
            world.renderableComponents[markedEntityID] != nil &&
            world.lifetimeComponents[markedEntityID] != nil
        markedAnotherEntity = world.entity(for: entityToMark)?.markForRemoval() ?? false
    }
}
