/// Maps raw platform-neutral input into transient Simulation commands.
///
/// This foundational system is the device-to-semantics boundary inside one
/// completed tick. Camera control consumes only its mapped command values, not
/// AppKit events or cumulative Input Runtime publications.
struct SInputMapping: PSystem {
    let pointerOrbitSensitivity: Float
    let scrollZoomSensitivity: Float

    init(pointerOrbitSensitivity: Float, scrollZoomSensitivity: Float) {
        precondition(pointerOrbitSensitivity.isFinite, "Pointer orbit sensitivity must be finite.")
        precondition(scrollZoomSensitivity.isFinite, "Scroll zoom sensitivity must be finite.")

        self.pointerOrbitSensitivity = pointerOrbitSensitivity
        self.scrollZoomSensitivity = scrollZoomSensitivity
    }

    mutating func update(world: inout World, deltaTime: Float) {
        let cameraOrbitYawDelta = world.input.mouse.delta.x * pointerOrbitSensitivity
        world.input.actions.cameraOrbitYawDelta = cameraOrbitYawDelta.isFinite ? cameraOrbitYawDelta : 0

        let cameraZoomDelta = world.input.mouse.scrollDelta.y * scrollZoomSensitivity
        world.input.actions.cameraZoomDelta = cameraZoomDelta.isFinite ? cameraZoomDelta : 0
    }
}
