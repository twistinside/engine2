import Testing
@testable import Engine2

struct PSelectableTests {
    @Test func selectionValuesReadFromWorldStores() async throws {
        let world = World()
        let entity = TestSelectableEntity(
            unregisteredID: EntityID(index: 0, generation: 0),
            in: world
        )
        let expectedState = CSelectable.SelectionState.highlighted
        let expectedRadius = 3.5
        let selectable = CSelectable(selectionState: expectedState)

        world.positionComponents.insert(CPosition(position: .zero), for: entity.id)
        world.selectionBoundsComponents.insert(CSelectionBounds(radius: expectedRadius), for: entity.id)
        world.selectableComponents.insert(
            selectable,
            for: entity.id
        )

        #expect(entity.selectionRadius == expectedRadius)
        #expect(entity.selectionState == expectedState)
    }
}

private extension PSelectableTests {
    private final class TestSelectableEntity: Entity, PSelectable {}
}
