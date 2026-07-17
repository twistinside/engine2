/// Clears one-step input deltas after every fixed input step.
struct SInputCleanup: PSystem {
    mutating func update(world: inout World, deltaTime: Float) {
        world.input.clearTransientInput()
    }
}
