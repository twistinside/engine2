/// Converts raw input state into engine-level action values.
struct SInputMapping: PSystem {
    let diagnosticsID: SimulationSystemID? = .inputMapping

    var pointerOrbitSensitivity: Float = 0.01
    var scrollZoomSensitivity: Float = 0.04

    mutating func update(world: inout World, deltaTime: Float) {
        world.input.actions.cameraOrbitDelta = world.input.mouse.delta * pointerOrbitSensitivity
        world.input.actions.cameraZoomDelta = world.input.mouse.scrollDelta.y * scrollZoomSensitivity
    }
}
