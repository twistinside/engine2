import Testing
@testable import Engine2

struct InteractableTests {
    @Test func interactionRangeReadsFromWorldStore() {
        let world = World()
        let entity = TestInteractableEntity(
            unregisteredID: EntityID(index: 0, generation: 0),
            in: world
        )
        let expectedRange = 140.0

        world.components[PositionComponent.self].insert(PositionComponent(position: .zero), for: entity.id)
        world.components[InteractionComponent.self].insert(InteractionComponent(interactionRange: expectedRange), for: entity.id)

        #expect(entity.interactionRange == expectedRange)
    }
}

private extension InteractableTests {
    private final class TestInteractableEntity: Entity, Interactable {}
}
