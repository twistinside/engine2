import Testing
@testable import Engine2

struct PSelectableTests {
    @Test func selectionStateReadsFromWorldStore() async throws {
        let world = World()
        let entity = TestSelectableEntity(unregisteredID: EntityID(index: 0, generation: 0), in: world)
        let expectedState = CSelectable.SelectionState.highlighted

        world.selectableComponents.insert(
            CSelectable(selectionState: expectedState),
            for: entity.id
        )

        #expect(entity.selectionState == expectedState)
    }
}

private final class TestSelectableEntity: Entity, PSelectable {}
