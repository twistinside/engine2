import Testing
@testable import Engine2

struct SInputMappingTests {
    @Test func mapsPositiveAndNegativeRawInputIntoCameraCommands() {
        var world = World()
        var system = SInputMapping(
            pointerOrbitSensitivity: 0.5,
            scrollZoomSensitivity: 2
        )

        world.input.mouse.delta = SIMD2<Float>(4, 99)
        world.input.mouse.scrollDelta = SIMD2<Float>(88, 5)
        system.update(world: &world, deltaTime: 1)

        #expect(world.input.actions.cameraOrbitYawDelta == 2)
        #expect(world.input.actions.cameraZoomDelta == 10)

        world.input.mouse.delta = SIMD2<Float>(-3, -99)
        world.input.mouse.scrollDelta = SIMD2<Float>(-88, -7)
        system.update(world: &world, deltaTime: 1)

        #expect(world.input.actions.cameraOrbitYawDelta == -1.5)
        #expect(world.input.actions.cameraZoomDelta == -14)
    }

    @Test func zeroRawInputProducesNeutralCommands() {
        var world = World()
        var system = SInputMapping(
            pointerOrbitSensitivity: 0.01,
            scrollZoomSensitivity: 0.04
        )
        world.input.actions.cameraOrbitYawDelta = 12
        world.input.actions.cameraZoomDelta = -9

        system.update(world: &world, deltaTime: 1)

        #expect(world.input.actions.cameraOrbitYawDelta == 0)
        #expect(world.input.actions.cameraZoomDelta == 0)
    }

    @Test func nonfiniteAndOverflowingProductsCannotPoisonCommands() {
        var world = World()
        var system = SInputMapping(
            pointerOrbitSensitivity: 2,
            scrollZoomSensitivity: 2
        )
        world.input.actions.cameraOrbitYawDelta = 12
        world.input.actions.cameraZoomDelta = -9

        world.input.mouse.delta.x = .nan
        world.input.mouse.scrollDelta.y = .infinity
        system.update(world: &world, deltaTime: 1)

        #expect(world.input.actions.cameraOrbitYawDelta == 0)
        #expect(world.input.actions.cameraZoomDelta == 0)

        world.input.mouse.delta.x = .greatestFiniteMagnitude
        world.input.mouse.scrollDelta.y = -.greatestFiniteMagnitude
        system.update(world: &world, deltaTime: 1)

        #expect(world.input.actions.cameraOrbitYawDelta == 0)
        #expect(world.input.actions.cameraZoomDelta == 0)
    }
}
