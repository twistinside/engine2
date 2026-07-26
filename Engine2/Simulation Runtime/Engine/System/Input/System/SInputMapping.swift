/// Maps raw platform-neutral input into transient Simulation commands.
///
/// This foundational system is the device-to-semantics boundary inside one
/// completed tick. Camera control consumes only its mapped command values, not
/// AppKit events or cumulative Input Runtime publications.
struct SInputMapping: PSystem {
    let pointerOrbitSensitivity: Float
    let scrollZoomSensitivity: Float

    init(pointerOrbitSensitivity: Float = 0.01, scrollZoomSensitivity: Float = 0.04) {
        precondition(pointerOrbitSensitivity.isFinite, "Pointer orbit sensitivity must be finite.")
        precondition(scrollZoomSensitivity.isFinite, "Scroll zoom sensitivity must be finite.")

        self.pointerOrbitSensitivity = pointerOrbitSensitivity
        self.scrollZoomSensitivity = scrollZoomSensitivity
    }

    mutating func update(world: inout World, deltaTime: Float) {
        world.input.actions.cameraOrbitYawDelta = Self.finiteProduct(
            world.input.mouse.delta.x,
            pointerOrbitSensitivity
        )
        world.input.actions.cameraZoomDelta = Self.finiteProduct(
            world.input.mouse.scrollDelta.y,
            scrollZoomSensitivity
        )
    }

    private static func finiteProduct(_ lhs: Float, _ rhs: Float) -> Float {
        let product = lhs * rhs
        return product.isFinite ? product : 0
    }
}
