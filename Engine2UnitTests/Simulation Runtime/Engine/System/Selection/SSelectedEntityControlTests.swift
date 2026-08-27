import Testing
@testable import Engine2

struct SSelectedEntityControlTests {
    @Test func routesHeldSemanticsOnlyToTheSelectedControllableEntity() {
        var world = MiningWorldBuilder().buildWorld()
        let skiffID = world.playerControlComponents.entities[0]
        world.input.translation = SIMD2<Float>(0.25, -0.75)
        world.input.isInteractionActive = true
        var system = SSelectedEntityControl()

        system.update(world: &world, deltaTime: 1.0 / 60.0)

        #expect(world.playerControlComponents[skiffID]?.translation == SIMD2<Double>(0.25, -0.75))
        #expect(world.playerControlComponents[skiffID]?.isInteractionActive == true)
    }

    @Test func selectingANoncontrollableEntityClearsThePreviousCommand() {
        var world = MiningWorldBuilder().buildWorld()
        let skiffID = world.playerControlComponents.entities[0]
        let starID = world.gravitySourceComponents.entities[0]
        world.playerControlComponents.update(for: skiffID) { control in
            control.translation = SIMD2<Double>(1, 0)
            control.isInteractionActive = true
        }
        world.input.translation = SIMD2<Float>(0, 1)
        world.input.isInteractionActive = true
        world.select(starID)
        var system = SSelectedEntityControl()

        system.update(world: &world, deltaTime: 1.0 / 60.0)

        #expect(world.playerControlComponents[skiffID]?.translation == .zero)
        #expect(world.playerControlComponents[skiffID]?.isInteractionActive == false)
    }
}
