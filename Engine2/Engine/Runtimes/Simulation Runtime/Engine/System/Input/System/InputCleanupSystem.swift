/// Clears one-step input deltas after every fixed input step.
struct InputCleanupSystem: System {
    mutating func update(world: inout World, deltaTime: Double) {
        world.input.clearTransientInput()
    }
}
