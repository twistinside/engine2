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
        observedPendingRemoval = world.components[DestructibleComponent.self][markedEntityID]?.state == .pendingRemoval
        observedComponents = world.components[PositionComponent.self][markedEntityID] != nil &&
            world.components[RenderableComponent.self][markedEntityID] != nil &&
            world.components[LifetimeComponent.self][markedEntityID] != nil
        markedAnotherEntity = world.components[DestructibleComponent.self].update(for: entityToMark) { $0.state = .pendingRemoval }
    }
}
