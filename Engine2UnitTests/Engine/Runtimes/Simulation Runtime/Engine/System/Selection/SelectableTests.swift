import Testing
@testable import Engine2

struct SelectableTests {
    @Test func selectionValuesReadFromWorldStores() async throws {
        let world = World()
        let entity = TestSelectableEntity(
            unregisteredID: EntityID(index: 0, generation: 0),
            in: world
        )
        let expectedState = SelectableComponent.SelectionState.highlighted
        let expectedRadius = 3.5
        let selectable = SelectableComponent(selectionState: expectedState)

        world.positionComponents.insert(PositionComponent(position: .zero), for: entity.id)
        world.selectionBoundsComponents.insert(SelectionBoundsComponent(radius: expectedRadius), for: entity.id)
        world.selectableComponents.insert(
            selectable,
            for: entity.id
        )

        #expect(entity.selectionRadius == expectedRadius)
        #expect(entity.selectionState == expectedState)
    }
}

private extension SelectableTests {
    private final class TestSelectableEntity: Entity, Selectable {}
}
