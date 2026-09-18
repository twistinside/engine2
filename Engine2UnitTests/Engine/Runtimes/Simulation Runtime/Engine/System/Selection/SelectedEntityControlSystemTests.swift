import Testing
@testable import Engine2

struct SelectedEntityControlSystemTests {
    @Test func routesSemanticCommandsOnlyToTheSelectedControllableEntity() {
        var world = MiningWorldBuilder().buildWorld()
        let skiffID = world.components[PlayerControlComponent.self].entities[0]
        world.input.translation = SIMD2<Float>(0.25, -0.75)
        world.input.isInteractionActive = true
        world.input.isFireRequested = true
        var system = SelectedEntityControlSystem()

        system.update(world: &world, deltaTime: 1.0 / 60.0)

        #expect(world.components[PlayerControlComponent.self][skiffID]?.translation == SIMD2<Double>(0.25, -0.75))
        #expect(world.components[PlayerControlComponent.self][skiffID]?.interactionState == .active)
        #expect(world.components[PlayerControlComponent.self][skiffID]?.isFireRequested == true)

        world.input.clearTransientInput()
        system.update(world: &world, deltaTime: 1.0 / 60.0)

        #expect(world.components[PlayerControlComponent.self][skiffID]?.isFireRequested == false)
        #expect(world.components[PlayerControlComponent.self][skiffID]?.interactionState == .active)
    }

    @Test func selectingANoncontrollableEntityClearsThePreviousCommand() {
        var world = MiningWorldBuilder().buildWorld()
        let skiffID = world.components[PlayerControlComponent.self].entities[0]
        let starID = world.components[GravitySourceComponent.self].entities[0]
        world.components[PlayerControlComponent.self].update(for: skiffID) { control in
            control.translation = SIMD2<Double>(1, 0)
            control.interactionState = .active
            control.isFireRequested = true
        }
        world.input.translation = SIMD2<Float>(0, 1)
        world.input.isInteractionActive = true
        world.input.isFireRequested = true
        world.select(starID)
        var system = SelectedEntityControlSystem()

        system.update(world: &world, deltaTime: 1.0 / 60.0)

        #expect(world.components[PlayerControlComponent.self][skiffID]?.translation == .zero)
        #expect(world.components[PlayerControlComponent.self][skiffID]?.interactionState == .inactive)
        #expect(world.components[PlayerControlComponent.self][skiffID]?.isFireRequested == false)
    }
}
