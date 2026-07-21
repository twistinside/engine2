/// Clears one-step input deltas after every fixed input step.
struct SInputCleanup: PSystem {
    let diagnosticsID: SimulationSystemID? = .inputCleanup

    mutating func update(world: inout World, deltaTime: Float) {
        world.input.clearTransientInput()
    }
}
