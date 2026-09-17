import Testing
@testable import Engine2

struct PlanarSelectionSystemTests {
    @Test func centerPressSelectsTheNearestBoundedEntity() {
        var world = World()
        world.camera = Camera.lookingAt(
            .zero,
            from: SIMD3<Float>(0, 0, 10),
            up: SIMD3<Float>(0, 1, 0),
            projection: .perspective(
                verticalFieldOfView: .pi / 3,
                near: 0.1,
                far: 100
            )
        )
        let nearer = addSelectableEntity(at: .zero, radius: 1, to: world)
        let farther = addSelectableEntity(
            at: SIMD3<Double>(0, 0, -4),
            radius: 1,
            to: world
        )
        world.select(farther.id)
        world.input.selectionPress = SelectionPress(
            normalizedPosition: SIMD2<Float>(repeating: 0.5),
            aspectRatio: 1
        )
        var system = PlanarSelectionSystem()

        system.update(world: &world, deltaTime: 1.0 / 60.0)

        #expect(world.selectedEntityID == nearer.id)
        #expect(nearer.selectionState == .selected)
        #expect(farther.selectionState == .unselected)
    }

    @Test func pressWithoutAHitClearsTheCurrentSelection() {
        var world = World()
        world.camera = Camera.lookingAt(
            .zero,
            from: SIMD3<Float>(0, 0, 10),
            up: SIMD3<Float>(0, 1, 0),
            projection: .perspective(
                verticalFieldOfView: .pi / 3,
                near: 0.1,
                far: 100
            )
        )
        let entity = addSelectableEntity(at: .zero, radius: 0.25, to: world)
        world.select(entity.id)
        world.input.selectionPress = SelectionPress(
            normalizedPosition: SIMD2<Float>(0.99, 0.99),
            aspectRatio: 1
        )
        var system = PlanarSelectionSystem()

        system.update(world: &world, deltaTime: 1.0 / 60.0)

        #expect(world.selectedEntityID == nil)
        #expect(entity.selectionState == .unselected)
    }

    private func addSelectableEntity(
        at position: SIMD3<Double>,
        radius: Double,
        to world: World
    ) -> TestBoundedEntity {
        let entity = TestBoundedEntity(
            unregisteredID: world.reserveEntityID(),
            in: world
        )
        world.add(
            entity,
            from: Entity.InitialState(
                position: position,
                selectionState: .unselected,
                selectionRadius: radius
            )
        )
        return entity
    }
}

private extension PlanarSelectionSystemTests {
    final class TestBoundedEntity: Entity, Selectable {}
}
