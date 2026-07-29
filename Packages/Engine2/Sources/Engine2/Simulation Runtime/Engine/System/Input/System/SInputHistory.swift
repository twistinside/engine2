/// Projects authoritative input into bounded diagnostic history before cleanup.
struct SInputHistory: PSystem {
    mutating func update(world: inout World, deltaTime _: Float) {
        world.inputHistory.record(input: world.input)
    }
}
